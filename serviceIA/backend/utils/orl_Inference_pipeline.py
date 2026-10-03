import sys
import os
import numpy as np
from PIL import Image
import onnxruntime as ort

# ==============================
# Classes (IMPORTANT: même ordre que l'entraînement)
# Ordre alphabétique strict imposé par torchvision.datasets.ImageFolder
# ==============================

class_names = [
    'aspect post tympanoplastie',   # 0
    'bouchon de cerumen',           # 1
    'cholestéatome',                # 2
    'corps étranger oreille',       # 3
    'myringosclerose',              # 4
    'otite moyenne aigue',          # 5  ← "otite*" < "otomy*" alphabétiquement
    'otite séromuqueuse',           # 6
    'otomycose',                    # 7
    'perforation tympanique',       # 8
    'tympan normal'                 # 9
]

# ==============================
# Fonction utilitaire pour les chemins PyInstaller
# ==============================

def get_resource_path(relative_path):
    """
    Retourne le chemin absolu vers une ressource.
    Fonctionne que ce soit en développement ou dans un exe PyInstaller.
    """
    try:
        # PyInstaller crée une variable _MEIPASS quand c'est un exe
        base_path = sys._MEIPASS
    except AttributeError:
        # Mode développement - chemin relatif au script
        base_path = os.path.dirname(os.path.abspath(__file__))

    return os.path.join(base_path, relative_path)

# ==============================
# Chargement du modèle ONNX
# ==============================

def load_model(model_path):
    """
    Charge le modèle ONNX avec onnxruntime (CPU uniquement pour compatibilité)
    """
    # Résoudre le chemin (PyInstaller compatible)
    full_model_path = get_resource_path(model_path)

    if not os.path.exists(full_model_path):
        raise FileNotFoundError(f"Modèle ONNX non trouvé: {full_model_path}")

    # Utiliser CPU pour compatibilité maximale (pas de CUDA requis)
    providers = ['CPUExecutionProvider']

    try:
        session = ort.InferenceSession(full_model_path, providers=providers)
        print(f"✅ Modèle ONNX chargé avec succès: {full_model_path}")
        return session
    except Exception as e:
        raise RuntimeError(f"Erreur chargement modèle ONNX: {e}")

# ==============================
# Prétraitement de l'image (même qu'avant)
# ==============================

def preprocess_image(image):
    """
    Prétraitement identique à PyTorch pour compatibilité
    image: PIL Image
    """
    # Redimensionnement
    image = image.resize((224, 224))

    # Conversion en array numpy
    img_array = np.array(image).astype(np.float32)

    # Normalisation ImageNet (même valeurs que PyTorch)
    mean = np.array([0.485, 0.456, 0.406])
    std = np.array([0.229, 0.224, 0.225])

    # Normalisation par canal (HWC -> CHW)
    img_array = img_array / 255.0
    img_array = (img_array - mean) / std

    # Transposition HWC -> CHW (canal first)
    img_array = np.transpose(img_array, (2, 0, 1))

    # Ajout dimension batch
    img_array = np.expand_dims(img_array, axis=0)

    return img_array.astype(np.float32)

# ==============================
# Prédiction avec ONNX
# ==============================

def predict_top3(session, image):
    """
    Prédiction avec top 3 classes et leurs confiances
    session: ONNX Runtime session
    image: PIL Image
    """
    # Prétraitement
    input_data = preprocess_image(image)

    # Noms des entrées/sorties du modèle ONNX
    input_name = session.get_inputs()[0].name
    output_name = session.get_outputs()[0].name

    # Inférence
    outputs = session.run([output_name], {input_name: input_data})

    # Récupération des probabilités
    probabilities = outputs[0][0]  # Enlever dimension batch

    # Softmax numériquement stable (soustraction du max pour éviter les NaN)
    logits = probabilities - np.max(probabilities)
    probabilities = np.exp(logits) / np.sum(np.exp(logits))

    # Top 3
    top3_indices = np.argsort(probabilities)[-3:][::-1]  # Top 3 décroissant
    top3 = [
        {
            "class": class_names[i],
            "confidence": round(probabilities[i] * 100, 2)
        }
        for i in top3_indices
    ]

    return top3
