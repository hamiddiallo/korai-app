"""
COMPARAISON PyTorch (.pth) vs ONNX (.onnx)
============================================
Compare les prédictions et performances des deux modèles
"""

import os
import time
import numpy as np
import torch
import torch.nn as nn
import onnxruntime as ort
from PIL import Image
from torchvision import transforms, models
from pathlib import Path
import pandas as pd
from collections import defaultdict

# =====================================================================
# CONFIGURATION
# =====================================================================
import sys
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))
from utils.orl_Inference_pipeline import class_names as PIPELINE_CLASSES

PTH_MODEL_PATH = BACKEND_DIR / "utils" / "checkpoints" / "best_efficientNetB0_final_all_ds.pth"
ONNX_MODEL_PATH = BACKEND_DIR / "efficientnet.onnx"
TEST_DIR = BACKEND_DIR / "test_set"

CLASSES = PIPELINE_CLASSES  # ordre alphabétique ImageFolder (corrige l'ancien bug d'ordre)

# Prétraitement standard pour EfficientNet
MEAN = [0.485, 0.456, 0.406]
STD = [0.229, 0.224, 0.225]

# Transformations pour PyTorch
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=MEAN, std=STD),
])


# =====================================================================
# CHARGEMENT DES MODÈLES
# =====================================================================
def load_pytorch_model(model_path, num_classes=10):
    """Charge le modèle PyTorch .pth"""
    print(f"\n📦 Chargement du modèle PyTorch: {model_path}")
    
    # Créer l'architecture EfficientNet-B0
    model = models.efficientnet_b0(pretrained=False)
    
    # Modifier la dernière couche pour le nombre de classes
    in_features = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(in_features, num_classes)
    
    # Charger les poids
    checkpoint = torch.load(model_path, map_location='cpu')
    
    # Gérer différents formats de sauvegarde
    if isinstance(checkpoint, dict):
        if 'model_state_dict' in checkpoint:
            model.load_state_dict(checkpoint['model_state_dict'])
        elif 'state_dict' in checkpoint:
            model.load_state_dict(checkpoint['state_dict'])
        else:
            model.load_state_dict(checkpoint)
    else:
        model = checkpoint
    
    model.eval()
    print(f"✅ Modèle PyTorch chargé avec succès")
    return model


def load_onnx_model(model_path):
    """Charge le modèle ONNX"""
    print(f"\n📦 Chargement du modèle ONNX: {model_path}")
    session = ort.InferenceSession(str(model_path))
    print(f"✅ Modèle ONNX chargé avec succès")
    return session


# =====================================================================
# PRÉDICTION
# =====================================================================
def predict_pytorch(model, image):
    """Prédiction avec PyTorch"""
    # Prétraitement
    img_tensor = transform(image).unsqueeze(0)
    
    # Inférence
    with torch.no_grad():
        outputs = model(img_tensor)
        probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
    
    # Top-3
    top3_probs, top3_indices = torch.topk(probabilities, 3)
    top3 = [(CLASSES[idx], float(prob)) for idx, prob in zip(top3_indices, top3_probs)]
    
    return top3


def predict_onnx(session, image):
    """Prédiction avec ONNX"""
    # Prétraitement (identique à PyTorch)
    img_tensor = transform(image).unsqueeze(0)
    img_numpy = img_tensor.numpy()
    
    # Inférence
    input_name = session.get_inputs()[0].name
    output_name = session.get_outputs()[0].name
    
    outputs = session.run([output_name], {input_name: img_numpy})
    probabilities = outputs[0][0]
    
    # Softmax manuel si nécessaire
    exp_probs = np.exp(probabilities - np.max(probabilities))
    probabilities = exp_probs / exp_probs.sum()
    
    # Top-3
    top3_indices = np.argsort(probabilities)[-3:][::-1]
    top3 = [(CLASSES[idx], float(probabilities[idx])) for idx in top3_indices]
    
    return top3


# =====================================================================
# CHARGEMENT DES IMAGES DE TEST
# =====================================================================
def load_test_images(test_dir):
    """Charge toutes les images de test avec leurs labels"""
    images = []
    if not test_dir.is_dir():
        raise FileNotFoundError(f"Dossier test introuvable : {test_dir}")
    
    for class_dir in test_dir.iterdir():
        if not class_dir.is_dir():
            continue
        true_label = class_dir.name
        if true_label not in CLASSES:
            print(f"⚠ Classe inconnue ignorée : {true_label}")
            continue
        for img_path in class_dir.iterdir():
            if img_path.suffix.lower() in (".jpg", ".jpeg", ".png"):
                images.append((img_path, true_label))
    
    print(f"\n📊 {len(images)} images chargées sur {len(set(l for _, l in images))} classes")
    return images


# =====================================================================
# ÉVALUATION
# =====================================================================
def evaluate_model(model, images, model_type="pytorch", onnx_session=None):
    """Évalue un modèle sur toutes les images"""
    results = []
    latencies = []
    
    print(f"\n🔄 Évaluation du modèle {model_type.upper()}...")
    
    for i, (img_path, true_label) in enumerate(images, 1):
        try:
            image = Image.open(img_path).convert("RGB")
        except Exception as e:
            print(f"⚠ Erreur image {img_path.name}: {e}")
            continue
        
        # Mesure de latence
        t0 = time.perf_counter()
        
        if model_type == "pytorch":
            top3 = predict_pytorch(model, image)
        else:  # onnx
            top3 = predict_onnx(onnx_session, image)
        
        latency_ms = (time.perf_counter() - t0) * 1000
        latencies.append(latency_ms)
        
        top1_pred = top3[0][0]
        top1_correct = (top1_pred == true_label)
        top3_correct = (true_label in [c for c, _ in top3])
        
        results.append({
            "image": img_path.name,
            "true_label": true_label,
            "top1_pred": top1_pred,
            "top1_correct": top1_correct,
            "top3_correct": top3_correct,
            "top1_conf": top3[0][1],
            "top3": [c for c, _ in top3],
        })
        
        if i % 10 == 0:
            print(f"  {i}/{len(images)} images traitées")
    
    # Calcul des métriques
    top1_acc = sum(r["top1_correct"] for r in results) / len(results)
    top3_acc = sum(r["top3_correct"] for r in results) / len(results)
    
    # Par classe
    class_stats = defaultdict(lambda: {"total": 0, "correct": 0})
    for r in results:
        class_stats[r["true_label"]]["total"] += 1
        if r["top1_correct"]:
            class_stats[r["true_label"]]["correct"] += 1
    
    return {
        "results": results,
        "top1_acc": top1_acc,
        "top3_acc": top3_acc,
        "latencies": latencies,
        "class_stats": dict(class_stats),
    }


# =====================================================================
# AFFICHAGE DES RÉSULTATS
# =====================================================================
def print_comparison(pytorch_metrics, onnx_metrics):
    """Affiche la comparaison des deux modèles"""
    print("\n" + "="*80)
    print("  COMPARAISON DES PERFORMANCES")
    print("="*80)
    
    print("\n📊 MÉTRIQUES GLOBALES:")
    print("-"*80)
    print(f"{'Métrique':<25} {'PyTorch (.pth)':<20} {'ONNX (.onnx)':<20} {'Différence':<15}")
    print("-"*80)
    
    top1_diff = pytorch_metrics["top1_acc"] - onnx_metrics["top1_acc"]
    top3_diff = pytorch_metrics["top3_acc"] - onnx_metrics["top3_acc"]
    
    print(f"{'Top-1 Accuracy':<25} {pytorch_metrics['top1_acc']*100:>6.2f}%        {onnx_metrics['top1_acc']*100:>6.2f}%        {top1_diff*100:>+6.2f}%")
    print(f"{'Top-3 Accuracy':<25} {pytorch_metrics['top3_acc']*100:>6.2f}%        {onnx_metrics['top3_acc']*100:>6.2f}%        {top3_diff*100:>+6.2f}%")
    
    # Latences
    pytorch_lat = np.mean(pytorch_metrics["latencies"])
    onnx_lat = np.mean(onnx_metrics["latencies"])
    lat_diff = pytorch_lat - onnx_lat
    
    print(f"\n{'Latence moyenne (ms)':<25} {pytorch_lat:>6.2f} ms      {onnx_lat:>6.2f} ms      {lat_diff:>+6.2f} ms")
    print(f"{'Latence médiane (ms)':<25} {np.median(pytorch_metrics['latencies']):>6.2f} ms      {np.median(onnx_metrics['latencies']):>6.2f} ms")
    print(f"{'Latence p95 (ms)':<25} {np.percentile(pytorch_metrics['latencies'], 95):>6.2f} ms      {np.percentile(onnx_metrics['latencies'], 95):>6.2f} ms")
    
    print("\n📈 PERFORMANCES PAR CLASSE (Top-1 Accuracy):")
    print("-"*80)
    print(f"{'Classe':<30} {'PyTorch':<15} {'ONNX':<15} {'Différence':<15}")
    print("-"*80)
    
    all_classes = set(pytorch_metrics["class_stats"].keys()) | set(onnx_metrics["class_stats"].keys())
    for cls in sorted(all_classes):
        pytorch_stats = pytorch_metrics["class_stats"].get(cls, {"total": 0, "correct": 0})
        onnx_stats = onnx_metrics["class_stats"].get(cls, {"total": 0, "correct": 0})
        
        pytorch_acc = pytorch_stats["correct"] / pytorch_stats["total"] if pytorch_stats["total"] > 0 else 0
        onnx_acc = onnx_stats["correct"] / onnx_stats["total"] if onnx_stats["total"] > 0 else 0
        
        diff = pytorch_acc - onnx_acc
        
        status = "⚠️" if abs(diff) > 0.3 else "✅"
        print(f"{cls:<30} {pytorch_acc*100:>5.1f}% ({pytorch_stats['correct']}/{pytorch_stats['total']})     {onnx_acc*100:>5.1f}% ({onnx_stats['correct']}/{onnx_stats['total']})     {diff*100:>+5.1f}% {status}")
    
    print("\n🏁 CONCLUSION:")
    print("-"*80)
    if top1_diff > 0.1:
        print(f"⚠️  La conversion ONNX a dégradé la précision de {top1_diff*100:.1f}%")
        print(f"   → Le modèle PyTorch original est significativement meilleur")
    elif top1_diff > 0.05:
        print(f"⚠️  Légère dégradation lors de la conversion ONNX ({top1_diff*100:.1f}%)")
    else:
        print(f"✅ La conversion ONNX a bien préservé les performances")
    
    speedup = pytorch_lat / onnx_lat if onnx_lat > 0 else 0
    print(f"   → Vitesse d'inférence: ONNX est {speedup:.1f}x plus rapide")


def save_detailed_comparison(pytorch_metrics, onnx_metrics, output_path=str(BACKEND_DIR / "evaluation" / "model_comparison.csv")):
    """Sauvegarde la comparaison détaillée dans un CSV"""
    data = []
    
    for r in pytorch_metrics["results"]:
        # Trouver la correspondance dans ONNX
        onnx_result = next((o for o in onnx_metrics["results"] if o["image"] == r["image"]), None)
        
        data.append({
            "image": r["image"],
            "true_label": r["true_label"],
            "pytorch_top1": r["top1_pred"],
            "pytorch_correct": r["top1_correct"],
            "pytorch_confidence": r["top1_conf"],
            "onnx_top1": onnx_result["top1_pred"] if onnx_result else None,
            "onnx_correct": onnx_result["top1_correct"] if onnx_result else None,
            "onnx_confidence": onnx_result["top1_conf"] if onnx_result else None,
            "agreement": r["top1_pred"] == onnx_result["top1_pred"] if onnx_result else False,
        })
    
    df = pd.DataFrame(data)
    df.to_csv(output_path, index=False, encoding='utf-8-sig')
    print(f"\n💾 Comparaison détaillée sauvegardée: {output_path}")


# =====================================================================
# MAIN
# =====================================================================
def main():
    print("="*80)
    print("  COMPARAISON PyTorch (.pth) vs ONNX (.onnx)")
    print("="*80)
    
    # Charger les images de test
    images = load_test_images(TEST_DIR)
    if not images:
        print("❌ Aucune image trouvée!")
        return
    
    # Charger les modèles
    pytorch_model = load_pytorch_model(PTH_MODEL_PATH)
    onnx_session = load_onnx_model(ONNX_MODEL_PATH)
    
    # Évaluer PyTorch
    pytorch_metrics = evaluate_model(pytorch_model, images, "pytorch")
    
    # Évaluer ONNX
    onnx_metrics = evaluate_model(None, images, "onnx", onnx_session)
    
    # Afficher comparaison
    print_comparison(pytorch_metrics, onnx_metrics)
    
    # Sauvegarder résultats
    save_detailed_comparison(pytorch_metrics, onnx_metrics)
    
    print("\n✅ Analyse terminée!")

if __name__ == "__main__":
    main()