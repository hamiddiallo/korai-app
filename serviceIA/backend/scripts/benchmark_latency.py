"""
KORAI ORL - Benchmark de latence reel
Mesure : ONNX vision + ChromaDB retrieval
Produit : backend/figures_soutenance/latency_real.csv
"""
import os, sys, time, csv, statistics
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

import numpy as np
from PIL import Image
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
RESULTS_OUT = BACKEND_DIR / "evaluation" / "latency_real.csv"
RESULTS_OUT.parent.mkdir(exist_ok=True)

ONNX_MODEL   = BACKEND_DIR / "efficientnet.onnx"
CHROMA_DIR   = BACKEND_DIR / "KORAI-APP" / "chroma_db"
COLLECTION   = "orl_knowledge_base"
EMBED_MODEL  = "intfloat/multilingual-e5-base"
N_RUNS       = 30

def dummy_image():
    arr = np.random.randint(0, 255, (224, 224, 3), dtype=np.uint8)
    return Image.fromarray(arr)

# ── 1. ONNX Inference ─────────────────────────────────────────────────
def bench_onnx():
    if not ONNX_MODEL.exists():
        print(f"  [!] Modele ONNX introuvable : {ONNX_MODEL}")
        return None

    import onnxruntime as ort
    from utils.orl_Inference_pipeline import preprocess_image

    session = ort.InferenceSession(str(ONNX_MODEL), providers=["CPUExecutionProvider"])
    input_name  = session.get_inputs()[0].name
    output_name = session.get_outputs()[0].name

    times = []
    for _ in range(N_RUNS):
        img = dummy_image()
        t0  = time.perf_counter()
        arr = preprocess_image(img)
        session.run([output_name], {input_name: arr})
        times.append((time.perf_counter() - t0) * 1000)

    return times


# ── 2. ChromaDB MMR Retrieval ─────────────────────────────────────────
def bench_chroma():
    if not CHROMA_DIR.exists():
        print(f"  [!] ChromaDB introuvable : {CHROMA_DIR}")
        return None

    from langchain_community.embeddings import HuggingFaceEmbeddings
    from langchain_community.vectorstores import Chroma

    class _E5Embeddings(HuggingFaceEmbeddings):
        def embed_query(self, text):
            return super().embed_query(f"query: {text}")
        def embed_documents(self, texts):
            return super().embed_documents([f"passage: {t}" for t in texts])

    print("  Chargement des embeddings (peut prendre ~30s)...")
    emb = _E5Embeddings(
        model_name=EMBED_MODEL,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )
    vs = Chroma(persist_directory=str(CHROMA_DIR),
                embedding_function=emb, collection_name=COLLECTION)
    retriever = vs.as_retriever(
        search_type="mmr",
        search_kwargs={"k": 6, "fetch_k": 25, "lambda_mult": 0.7},
    )

    queries = [
        "otalgie fievre otorrhee",
        "perforation tympanique traumatisme",
        "tympan bombé perte cone lumineux",
        "calcification tympan sequelle",
        "bouchon cerumen obstruction",
    ]

    times = []
    for q in queries * (N_RUNS // len(queries) + 1):
        t0 = time.perf_counter()
        retriever.invoke(q)
        times.append((time.perf_counter() - t0) * 1000)
    return times[:N_RUNS]


# ── 3. Rapport ────────────────────────────────────────────────────────
def report(label, times):
    if not times:
        print(f"  {label}: pas de donnees")
        return {}
    mean = statistics.mean(times)
    med  = statistics.median(times)
    p95  = sorted(times)[int(0.95 * len(times))]
    p99  = sorted(times)[int(0.99 * len(times))]
    mn   = min(times)
    mx   = max(times)
    print(f"\n  [{label}]")
    print(f"    Moyenne  : {mean:.2f} ms")
    print(f"    Mediane  : {med:.2f} ms")
    print(f"    P95      : {p95:.2f} ms")
    print(f"    P99      : {p99:.2f} ms")
    print(f"    Min/Max  : {mn:.2f} / {mx:.2f} ms")
    return {"label": label, "mean": round(mean,2), "median": round(med,2),
            "p95": round(p95,2), "p99": round(p99,2),
            "min": round(mn,2), "max": round(mx,2)}


if __name__ == "__main__":
    print("\n[*] Benchmark de latence KORAI ORL\n")

    sys.path.insert(0, str(BACKEND_DIR))

    print("[1/2] Inference ONNX (vision)...")
    onnx_times = bench_onnx()

    print("[2/2] Recuperation ChromaDB MMR...")
    chroma_times = bench_chroma()

    rows = []
    r = report("ONNX Vision (preprocessing + inference)", onnx_times)
    if r: rows.append(r)
    r = report("ChromaDB MMR (k=6, fetch_k=25)", chroma_times)
    if r: rows.append(r)

    if rows:
        with open(RESULTS_OUT, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["label","mean","median","p95","p99","min","max"])
            w.writeheader()
            w.writerows(rows)
        print(f"\n  Resultats sauvegardes -> {RESULTS_OUT}")

    print("\n  Note : pour la latence Mistral, mesurer manuellement via l'endpoint /chat/simple")
    print("  en notant le temps de reponse (typiquement 1500-3000ms selon la longueur).")
    print("\n[OK] Benchmark termine.\n")
