# Ubuntu 22.04 LTS — compatible AMD64 et ARM64 (Oracle Cloud Ampere)
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Python 3.11 + dépendances système pour onnxruntime, opencv-headless, grpcio
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    gcc \
    g++ \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3.11-distutils \
    python3-pip \
    libgomp1 \
    libglib2.0-0 \
    libgl1-mesa-glx \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Définir python3.11 comme python par défaut
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    python -m pip install --upgrade pip

# Installer les dépendances Python (couche cachée séparément)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier code + modèles ONNX + base ChromaDB initiale
COPY . .

EXPOSE 8000

# Healthcheck (curl installé ci-dessus)
HEALTHCHECK --interval=30s --timeout=15s --retries=5 --start-period=120s \
    CMD curl -f http://localhost:8000/health || exit 1

# 1 seul worker : ChromaDB et conversation_history sont en mémoire non partagée
CMD ["python", "-m", "uvicorn", "utils.rag_api:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]