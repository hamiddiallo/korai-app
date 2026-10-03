"""
KORAI ORL – Diagnostic rigoureux du module Vision
==================================================
Ce script effectue 5 phases d'analyse :

  Phase 0 : Audit des noms de classes (pipeline vs dossiers vs scripts)
  Phase 1 : Sanité du modèle ONNX (architecture, logits bruts, softmax)
  Phase 2 : Test des biais de prédiction (images aléatoires et noires)
  Phase 3 : Évaluation corrigée (mapping NFC + pluriel→singulier)
  Phase 4 : Analyse par image des erreurs et confusions

Usage :
    cd backend
    python diagnose_vision.py

Sorties :
    diagnosis/00_class_audit.txt
    diagnosis/01_model_sanity.txt
    diagnosis/02_bias_test.txt
    diagnosis/03_evaluation_corrigee/  (confusion_matrix.png + metrics.csv)
    diagnosis/04_errors_per_image.csv
"""

import sys
import os
import time
import csv
import json
import unicodedata
from pathlib import Path    
from collections import Counter, defaultdict

import numpy as np
from PIL import Image

# ── Compatibilité encodage terminal Windows ──────────────────────────────────
sys.stdout.reconfigure(encoding="utf-8")

# ── Paths ─────────────────────────────────────────────────────────────────────
BACKEND_DIR  = Path(__file__).resolve().parent.parent
MODEL_PATH   = BACKEND_DIR / "efficientnet.onnx"
CHECKPOINT   = BACKEND_DIR / "utils" / "checkpoints" / "best_efficientNetB0_final_all_ds.pth"
TEST_DIR     = BACKEND_DIR / "test_set"
OUT_DIR      = BACKEND_DIR / "evaluation" / "diagnosis"
OUT_DIR.mkdir(parents=True, exist_ok=True)
(OUT_DIR / "03_evaluation_corrigee").mkdir(exist_ok=True)

sys.path.insert(0, str(BACKEND_DIR))

# ── Import pipeline ───────────────────────────────────────────────────────────
from utils.orl_Inference_pipeline import load_model, predict_top3, preprocess_image
from utils.orl_Inference_pipeline import class_names as PIPELINE_CLASSES

import onnxruntime as ort


# =============================================================================
# UTILITAIRES
# =============================================================================

def nfc(s: str) -> str:
    return unicodedata.normalize("NFC", s)

def nfd(s: str) -> str:
    return unicodedata.normalize("NFD", s)

def codepoints(s: str) -> str:
    return " ".join(f"U+{ord(c):04X}" for c in s if ord(c) > 127) or "(aucun)"

def sep(title: str = "", width: int = 70) -> str:
    if title:
        pad = (width - len(title) - 2) // 2
        return "=" * pad + f" {title} " + "=" * (width - pad - len(title) - 2)
    return "=" * width

def write(f, line: str = ""):
    print(line)
    f.write(line + "\n")


# =============================================================================
# PHASE 0 – AUDIT DES NOMS DE CLASSES
# =============================================================================

def phase0_class_audit():
    print("\n" + sep("PHASE 0 : AUDIT DES NOMS DE CLASSES"))

    # Classes dans les scripts d'évaluation précédents
    EVAL_CLASSES = [
        "aspect post tympanoplastie",
        "bouchon de cerumen",
        "cholestéatome",
        "corps étranger oreille",   # SINGULIER dans les scripts evaluate_vision*.py
        "myringosclerose",
        "otomycose",
        "otite moyenne aigue",
        "otite séromuqueuse",
        "perforation tympanique",
        "tympan normal",
    ]

    # Dossiers présents dans test_set/
    if TEST_DIR.is_dir():
        folders = sorted(d.name for d in TEST_DIR.iterdir() if d.is_dir())
    else:
        folders = []

    with open(OUT_DIR / "00_class_audit.txt", "w", encoding="utf-8") as f:
        write(f, sep("AUDIT DES NOMS DE CLASSES – KORAI ORL"))
        write(f)

        # ── Tableau des 3 sources ──────────────────────────────────────────
        write(f, f"{'#':<4} {'PIPELINE (orl_Inference_pipeline.py)':<42} {'EVAL SCRIPTS':<42} {'DOSSIERS test_set/'}")
        write(f, "-" * 130)

        all_ok = True
        issues = []

        for i in range(10):
            pc  = nfc(PIPELINE_CLASSES[i]) if i < len(PIPELINE_CLASSES) else "MANQUANT"
            ec  = nfc(EVAL_CLASSES[i])     if i < len(EVAL_CLASSES) else "MANQUANT"
            fc  = nfc(folders[i])          if i < len(folders) else "MANQUANT"

            flag_pe = " [DIFF!]" if pc != ec else ""
            flag_pf = " [DIFF!]" if pc != fc else ""
            flag_ef = " [DIFF!]" if ec != fc else ""
            any_diff = flag_pe or flag_pf or flag_ef

            line = f"[{i}] {pc:<42} {ec:<42} {fc}{flag_pe}{flag_pf}{flag_ef}"
            write(f, line)

            if any_diff:
                all_ok = False
                issues.append({
                    "index": i,
                    "pipeline": pc,
                    "eval_scripts": ec,
                    "dossier": fc,
                    "diff_pipeline_eval": pc != ec,
                    "diff_pipeline_dossier": pc != fc,
                    "diff_eval_dossier": ec != fc,
                })

        write(f)
        write(f, sep("DÉTAIL UNICODE DES CLASSES AVEC ACCENTS"))
        write(f)
        write(f, f"{'Classe (pipeline NFC)':<42} {'Codepoints non-ASCII pipeline':<35} {'Codepoints non-ASCII dossier'}")
        write(f, "-" * 120)
        for i, pc in enumerate(PIPELINE_CLASSES):
            fc = folders[i] if i < len(folders) else ""
            write(f, f"{nfc(pc):<42} {codepoints(pc):<35} {codepoints(fc) if fc else 'N/A'}")

        write(f)
        write(f, sep("RÉSUMÉ DES INCOHÉRENCES"))
        write(f)

        if all_ok:
            write(f, "✅ Aucune incohérence détectée entre pipeline, scripts d'évaluation et dossiers.")
        else:
            write(f, f"⚠️  {len(issues)} incohérence(s) détectée(s) :")
            for issue in issues:
                write(f)
                write(f, f"  Classe [{issue['index']}]")
                if issue["diff_pipeline_eval"]:
                    write(f, f"    PIPELINE   : {repr(issue['pipeline'])}")
                    write(f, f"    EVAL       : {repr(issue['eval_scripts'])}")
                    write(f, f"    → Impact : le modèle prédit '{issue['pipeline']}' mais l'évaluateur")
                    write(f,  f"               attend '{issue['eval_scripts']}' → F1 = 0 artificiellement")
                if issue["diff_pipeline_dossier"]:
                    write(f, f"    PIPELINE   : {repr(issue['pipeline'])}")
                    write(f, f"    DOSSIER    : {repr(issue['dossier'])}")
                    write(f, f"    → Impact : les images du dossier '{issue['dossier']}' sont ignorées")
                    write(f,  f"               ou mal labellisées à l'évaluation")

        write(f)
        write(f, sep("MAPPING DE CORRECTION RECOMMANDÉ"))
        write(f)
        write(f, "Renommer le dossier test_set/ et corriger orl_Inference_pipeline.py :")
        write(f, "  Dossier actuel              → Dossier corrigé")
        write(f, "  'corps étranger oreille'    → 'corps étrangers oreille'")
        write(f, "  (ou)  modifier pipeline : 'corps étrangers oreille' → 'corps étranger oreille'")
        write(f)
        write(f, "Recommandation : aligner sur le singulier 'corps étranger oreille'")
        write(f, "car c'est le terme médical standard français pour un CE auriculaire unique.")

    print(f"  → Sauvegardé : {OUT_DIR / '00_class_audit.txt'}")
    return issues


# =============================================================================
# PHASE 1 – SANITÉ DU MODÈLE ONNX
# =============================================================================

def phase1_model_sanity(session: ort.InferenceSession):
    print("\n" + sep("PHASE 1 : SANITÉ DU MODÈLE ONNX"))

    with open(OUT_DIR / "01_model_sanity.txt", "w", encoding="utf-8") as f:
        write(f, sep("SANITÉ DU MODÈLE ONNX – KORAI ORL"))
        write(f)

        # ── Métadonnées ONNX ──────────────────────────────────────────────
        inp = session.get_inputs()[0]
        out = session.get_outputs()[0]
        write(f, "ARCHITECTURE")
        write(f, f"  Entrée  : {inp.name}  shape={inp.shape}  type={inp.type}")
        write(f, f"  Sortie  : {out.name}  shape={out.shape}  type={out.type}")
        write(f, f"  Nombre de classes (sorties) : {out.shape[1]}")

        expected_classes = 10
        ok = out.shape[1] == expected_classes
        write(f, f"  {'✅' if ok else '❌'} Attendu : {expected_classes} classes")

        # ── Checkpoint PyTorch ────────────────────────────────────────────
        write(f)
        write(f, "CHECKPOINT PYTORCH")
        if CHECKPOINT.exists():
            import torch
            ckpt = torch.load(str(CHECKPOINT), map_location="cpu", weights_only=False)
            if isinstance(ckpt, dict) and "classifier.1.bias" in ckpt:
                bias = ckpt["classifier.1.bias"]
                write(f, f"  Taille bias classificateur : {bias.shape[0]}")
                write(f, f"  {'✅' if bias.shape[0] == 10 else '❌'} Correspond à 10 classes")
            else:
                last_key = list(ckpt.keys())[-1]
                write(f, f"  Dernière clé : {last_key} → shape : {ckpt[last_key].shape}")
            write(f, f"  Métadonnées de classes dans le checkpoint : NON (OrderedDict pur)")
            write(f,  f"  → L'ordre des classes est implicite (alphabétique ImageFolder)")
        else:
            write(f, f"  ⚠️  Checkpoint introuvable : {CHECKPOINT}")

        # ── Test 1 : entrée nulle ─────────────────────────────────────────
        write(f)
        write(f, "TEST 1 : IMAGE NOIRE (entrée zéro)")
        dummy_zero = np.zeros((1, 3, 224, 224), dtype=np.float32)
        logits = session.run([out.name], {inp.name: dummy_zero})[0][0]
        probs  = np.exp(logits) / np.sum(np.exp(logits))
        top1   = np.argmax(probs)
        write(f, f"  Logits  : {np.round(logits, 3)}")
        write(f, f"  Softmax : {np.round(probs, 4)}")
        write(f, f"  Top-1   : [{top1}] {nfc(PIPELINE_CLASSES[top1])} ({probs[top1]*100:.2f}%)")
        write(f, f"  Entropie: {-np.sum(probs * np.log(probs + 1e-9)):.4f} (max théorique = {np.log(10):.4f})")

        # ── Test 2 : entrée aléatoire (10 tirages) ─────────────────────────
        write(f)
        write(f, "TEST 2 : 10 IMAGES ALÉATOIRES (bruit gaussien)")
        random_preds = []
        for seed in range(10):
            np.random.seed(seed)
            rand_input = np.random.randn(1, 3, 224, 224).astype(np.float32)
            logits_r = session.run([out.name], {inp.name: rand_input})[0][0]
            probs_r  = np.exp(logits_r) / np.sum(np.exp(logits_r))
            pred_idx = int(np.argmax(probs_r))
            random_preds.append(pred_idx)
            write(f, f"  seed={seed}: top1=[{pred_idx}] {nfc(PIPELINE_CLASSES[pred_idx])} ({probs_r[pred_idx]*100:.1f}%)")

        cnt = Counter(random_preds)
        write(f)
        write(f, "  Distribution des prédictions sur bruit :")
        for cls_idx, count in cnt.most_common():
            bar = "█" * count
            write(f, f"    [{cls_idx}] {nfc(PIPELINE_CLASSES[cls_idx]):<35} {bar} ({count}/10)")

        if len(cnt) == 1:
            write(f, "  ⚠️  Le modèle prédit TOUJOURS la même classe sur du bruit → biais fort.")
        elif len(cnt) <= 3:
            write(f, "  ⚠️  Prédictions très concentrées sur bruit → biais modéré.")
        else:
            write(f, "  ✅ Prédictions distribuées sur bruit → pas de biais évident.")

        # ── Test 3 : image blanche ─────────────────────────────────────────
        write(f)
        write(f, "TEST 3 : IMAGE BLANCHE (entrée = 1.0)")
        dummy_white = np.ones((1, 3, 224, 224), dtype=np.float32)
        logits_w = session.run([out.name], {inp.name: dummy_white})[0][0]
        probs_w  = np.exp(logits_w) / np.sum(np.exp(logits_w))
        top1_w   = int(np.argmax(probs_w))
        write(f, f"  Top-1   : [{top1_w}] {nfc(PIPELINE_CLASSES[top1_w])} ({probs_w[top1_w]*100:.2f}%)")

        # ── Test 4 : invariance à la normalisation ─────────────────────────
        write(f)
        write(f, "TEST 4 : VÉRIFICATION DU PRÉTRAITEMENT (normalisation ImageNet)")
        pil_img = Image.fromarray(
            np.random.randint(0, 256, (224, 224, 3), dtype=np.uint8)
        )
        preprocessed = preprocess_image(pil_img)
        write(f, f"  Shape après preprocess : {preprocessed.shape}")
        write(f, f"  Min / Max : {preprocessed.min():.3f} / {preprocessed.max():.3f}")
        write(f, f"  Moyenne   : {preprocessed.mean():.3f} (attendu ≈ 0 après normalisation ImageNet)")
        write(f, f"  Std       : {preprocessed.std():.3f}  (attendu ≈ 1)")
        mean_ok = abs(preprocessed.mean()) < 1.0
        write(f, f"  {'✅' if mean_ok else '⚠️ '} Normalisation {'correcte' if mean_ok else 'suspecte'}")

    print(f"  → Sauvegardé : {OUT_DIR / '01_model_sanity.txt'}")


# =============================================================================
# PHASE 2 – TEST DE BIAIS SUR LES CLASSES PROBLÉMATIQUES
# =============================================================================

def phase2_bias_test(session: ort.InferenceSession):
    print("\n" + sep("PHASE 2 : BIAIS SUR CLASSES PROBLÉMATIQUES"))

    inp_name = session.get_inputs()[0].name
    out_name = session.get_outputs()[0].name

    problematic = [
        "cholestéatome",
        "corps étranger oreille",
        "otomycose",
        "otite moyenne aigue",
        "otite séromuqueuse",
    ]

    with open(OUT_DIR / "02_bias_test.txt", "w", encoding="utf-8") as f:
        write(f, sep("TEST DE BIAIS – CLASSES F1=0"))
        write(f)
        write(f, "Pour chaque classe problématique : on prédit toutes ses images et")
        write(f, "on regarde vers quoi le modèle les redirige systématiquement.")
        write(f)

        for cls_name in problematic:
            # Trouver le dossier correspondant (NFC-safe)
            cls_dir = None
            if TEST_DIR.is_dir():
                for d in TEST_DIR.iterdir():
                    if nfc(d.name) == nfc(cls_name) and d.is_dir():
                        cls_dir = d
                        break

            write(f, f"─── Classe : {cls_name} ───")
            if cls_dir is None or not cls_dir.is_dir():
                write(f, f"  ⚠️  Dossier introuvable pour cette classe.")
                write(f)
                continue

            imgs = [p for p in cls_dir.iterdir()
                    if p.suffix.lower() in (".jpg", ".jpeg", ".png")]
            write(f, f"  Nombre d'images : {len(imgs)}")

            if not imgs:
                write(f, "  ⚠️  Aucune image dans ce dossier.")
                write(f)
                continue

            preds = []
            confs = []
            for img_path in imgs:
                try:
                    pil = Image.open(img_path).convert("RGB")
                    top3 = predict_top3(session, pil)
                    pred_cls   = nfc(top3[0]["class"])
                    pred_conf  = top3[0]["confidence"]
                    preds.append(pred_cls)
                    confs.append(pred_conf)
                    write(f, f"  {img_path.name:<45} → {pred_cls} ({pred_conf:.1f}%)")
                except Exception as e:
                    write(f, f"  {img_path.name:<45} → ERREUR: {e}")

            if preds:
                cnt = Counter(preds)
                write(f)
                write(f, "  Résumé des prédictions :")
                for p, c in cnt.most_common():
                    match = "✅" if nfc(p) == nfc(cls_name) else "❌"
                    write(f, f"    {match} {p:<40} {c}x  (conf moy: {np.mean([confs[i] for i,pr in enumerate(preds) if pr==p]):.1f}%)")
                correct = sum(1 for p in preds if nfc(p) == nfc(cls_name))
                write(f, f"  Précision brute : {correct}/{len(preds)} = {correct/len(preds)*100:.0f}%")
            write(f)

    print(f"  → Sauvegardé : {OUT_DIR / '02_bias_test.txt'}")


# =============================================================================
# PHASE 3 – ÉVALUATION CORRIGÉE
# =============================================================================

def phase3_evaluation_corrigee(session: ort.InferenceSession):
    """
    Évaluation avec mapping NFC + singulier/pluriel corrigé.
    On utilise les noms de dossiers comme ground-truth,
    et on fait correspondre les prédictions du modèle via un alias_map.
    """
    print("\n" + sep("PHASE 3 : ÉVALUATION CORRIGÉE"))

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        import seaborn as sns
        from sklearn.metrics import (
            confusion_matrix, classification_report,
            accuracy_score, f1_score
        )
        HAS_SKLEARN = True
    except ImportError:
        print("  ⚠️  matplotlib/seaborn/sklearn non disponibles – skip figure")
        HAS_SKLEARN = False

    if not TEST_DIR.is_dir():
        print(f"  ⚠️  test_set introuvable : {TEST_DIR}")
        return []

    # ── Mapping : nom pipeline → nom dossier (NFC, singulier) ─────────────
    # On normalise en NFC et on corrige le pluriel/singulier connu
    alias_map = {
        nfc(c): nfc(c) for c in PIPELINE_CLASSES
    }
    # Correction explicite du cas problématique détecté
    alias_map["corps étrangers oreille"] = "corps étranger oreille"

    # Classes dans l'ordre des dossiers (NFC)
    folders = sorted(
        [d for d in TEST_DIR.iterdir() if d.is_dir()],
        key=lambda d: nfc(d.name)
    )
    EVAL_LABELS = [nfc(d.name) for d in folders]

    # Compter les images par dossier
    image_counts = {nfc(d.name): len([p for p in d.iterdir()
                    if p.suffix.lower() in (".jpg", ".jpeg", ".png")])
                    for d in folders}

    print(f"  Dossiers trouvés : {len(folders)}")
    for lbl in EVAL_LABELS:
        print(f"    {lbl} : {image_counts[lbl]} images")

    # ── Inférence ─────────────────────────────────────────────────────────
    results = []
    for folder in folders:
        true_label_nfc = nfc(folder.name)
        imgs = [p for p in folder.iterdir()
                if p.suffix.lower() in (".jpg", ".jpeg", ".png")]
        for img_path in imgs:
            try:
                pil = Image.open(img_path).convert("RGB")
                t0  = time.perf_counter()
                top3_raw = predict_top3(session, pil)
                lat = (time.perf_counter() - t0) * 1000

                # Appliquer le mapping alias
                pred_raw  = nfc(top3_raw[0]["class"])
                pred_mapped = alias_map.get(pred_raw, pred_raw)
                conf = top3_raw[0]["confidence"]

                top3_mapped = [alias_map.get(nfc(p["class"]), nfc(p["class"]))
                               for p in top3_raw]

                results.append({
                    "image":        img_path.name,
                    "folder":       folder.name,
                    "true":         true_label_nfc,
                    "pred_raw":     pred_raw,
                    "pred_mapped":  pred_mapped,
                    "correct_top1": pred_mapped == true_label_nfc,
                    "correct_top3": true_label_nfc in top3_mapped,
                    "confidence":   conf,
                    "latency_ms":   lat,
                })
            except Exception as e:
                print(f"    ⚠️  {img_path.name}: {e}")

    if not results:
        print("  ❌ Aucun résultat – arrêt de la phase 3")
        return []

    # ── Métriques ─────────────────────────────────────────────────────────
    y_true = [r["true"]        for r in results]
    y_pred = [r["pred_mapped"] for r in results]
    top1_acc = sum(r["correct_top1"] for r in results) / len(results)
    top3_acc = sum(r["correct_top3"] for r in results) / len(results)

    out_eval = OUT_DIR / "03_evaluation_corrigee"

    with open(out_eval / "rapport.txt", "w", encoding="utf-8") as f:
        write(f, sep("ÉVALUATION CORRIGÉE – KORAI ORL"))
        write(f)
        write(f, "Corrections appliquées :")
        write(f, "  1. Normalisation Unicode NFC sur tous les noms")
        write(f, "  2. Mapping 'corps étrangers oreille' → 'corps étranger oreille'")
        write(f)
        write(f, f"Images analysées : {len(results)}")
        write(f, f"Top-1 Accuracy   : {top1_acc*100:.2f}%")
        write(f, f"Top-3 Accuracy   : {top3_acc*100:.2f}%")

        if HAS_SKLEARN:
            report = classification_report(
                y_true, y_pred,
                labels=EVAL_LABELS,
                output_dict=True,
                zero_division=0,
            )
            write(f)
            write(f, f"{'Classe':<42} {'Précision':>10} {'Rappel':>10} {'F1':>10} {'Support':>10}")
            write(f, "-" * 85)
            for lbl in EVAL_LABELS:
                d = report.get(lbl, {})
                write(f, f"{lbl:<42} {d.get('precision',0):>10.3f} {d.get('recall',0):>10.3f}"
                         f" {d.get('f1-score',0):>10.3f} {int(d.get('support',0)):>10}")
            write(f)
            write(f, f"Macro F1  : {report.get('macro avg',{}).get('f1-score',0):.3f}")
            write(f, f"Weighted F1: {report.get('weighted avg',{}).get('f1-score',0):.3f}")

            # Matrice de confusion
            cm = confusion_matrix(y_true, y_pred, labels=EVAL_LABELS)
            short = [l[:18] for l in EVAL_LABELS]
            fig, ax = plt.subplots(figsize=(13, 11))
            sns.heatmap(cm, annot=True, fmt="d", cmap="Blues",
                        xticklabels=short, yticklabels=short, ax=ax)
            ax.set_xlabel("Prédit (modèle)", fontsize=11)
            ax.set_ylabel("Réel (dossier)", fontsize=11)
            ax.set_title(
                f"Matrice de confusion – EfficientNet-B0 ONNX (mapping corrigé)\n"
                f"Top-1 = {top1_acc*100:.1f}%  |  Top-3 = {top3_acc*100:.1f}%  |  n = {len(results)}",
                fontsize=12
            )
            plt.xticks(rotation=45, ha="right", fontsize=9)
            plt.yticks(rotation=0, fontsize=9)
            plt.tight_layout()
            plt.savefig(out_eval / "confusion_matrix.png", dpi=200)
            plt.close()
            print(f"  → Matrice sauvegardée : {out_eval / 'confusion_matrix.png'}")

    # CSV métriques par classe
    with open(out_eval / "metrics_per_class.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Classe", "Précision", "Rappel", "F1", "Support", "Top3_recall"])
        if HAS_SKLEARN:
            for lbl in EVAL_LABELS:
                d = report.get(lbl, {})
                top3_lbl = sum(1 for r in results if r["true"] == lbl and r["correct_top3"])
                sup = int(d.get("support", 0))
                t3r = f"{top3_lbl/sup:.3f}" if sup else "N/A"
                w.writerow([lbl,
                             f"{d.get('precision',0):.3f}",
                             f"{d.get('recall',0):.3f}",
                             f"{d.get('f1-score',0):.3f}",
                             sup, t3r])

    print(f"  → Rapport  : {out_eval / 'rapport.txt'}")
    print(f"  → CSV      : {out_eval / 'metrics_per_class.csv'}")
    return results


# =============================================================================
# PHASE 4 – ANALYSE PAR IMAGE
# =============================================================================

def phase4_per_image(results: list):
    print("\n" + sep("PHASE 4 : ANALYSE PAR IMAGE"))

    if not results:
        print("  Aucun résultat à analyser.")
        return

    errors = [r for r in results if not r["correct_top1"]]
    print(f"  Erreurs Top-1 : {len(errors)} / {len(results)}")

    with open(OUT_DIR / "04_errors_per_image.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["image", "dossier", "vrai_label", "predit_raw",
                    "predit_corrige", "confiance_%", "top3_correct", "latence_ms"])
        for r in sorted(results, key=lambda x: (x["correct_top1"], -x["confidence"])):
            w.writerow([
                r["image"], r["folder"], r["true"],
                r["pred_raw"], r["pred_mapped"],
                f"{r['confidence']:.1f}",
                "oui" if r["correct_top3"] else "non",
                f"{r['latency_ms']:.1f}",
            ])

    # Résumé des classes les plus confondues
    confusion_pairs = Counter()
    for r in errors:
        confusion_pairs[(r["true"], r["pred_mapped"])] += 1

    print("\n  Top confusions (vrai → prédit) :")
    for (true, pred), cnt in confusion_pairs.most_common(10):
        print(f"    {true:<35} → {pred:<35}  ({cnt}x)")

    print(f"  → CSV sauvegardé : {OUT_DIR / '04_errors_per_image.csv'}")


# =============================================================================
# MAIN
# =============================================================================

def main():
    print(sep("DIAGNOSTIC VISION – KORAI ORL"))
    print(f"Modèle  : {MODEL_PATH}")
    print(f"Tests   : {TEST_DIR}")
    print(f"Sorties : {OUT_DIR}")

    if not MODEL_PATH.exists():
        print(f"\n❌ Modèle ONNX introuvable : {MODEL_PATH}")
        return

    # Charger le modèle une seule fois
    session = ort.InferenceSession(str(MODEL_PATH),
                                   providers=["CPUExecutionProvider"])
    print("✅ Modèle ONNX chargé")

    issues  = phase0_class_audit()
    phase1_model_sanity(session)
    phase2_bias_test(session)
    results = phase3_evaluation_corrigee(session)
    phase4_per_image(results)

    print("\n" + sep("SYNTHÈSE"))
    print()
    if issues:
        print(f"⚠️  {len(issues)} incohérence(s) de noms de classes :")
        for issue in issues:
            if issue["diff_pipeline_eval"] or issue["diff_pipeline_dossier"]:
                print(f"   Classe [{issue['index']}] : '{issue['pipeline']}' ≠ '{issue['dossier']}'")
        print()
        print("  ACTION REQUISE : choisir un nom canonique et l'appliquer à :")
        print("    1. backend/utils/orl_Inference_pipeline.py  (class_names)")
        print("    2. backend/test_set/<dossier>/")
        print("    3. backend/evaluate_vision*.py  (liste CLASSES)")
    else:
        print("✅ Noms de classes cohérents entre pipeline, scripts et dossiers.")
    print()
    print(f"Résultats complets dans : {OUT_DIR}/")
    print(sep())


if __name__ == "__main__":
    main()
