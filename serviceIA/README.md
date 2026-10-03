# KORAI ORL — Version finale

Application d'aide au pré-diagnostic des pathologies de l'oreille : classification d'images otoscopiques (EfficientNet-B0, ONNX) et analyse documentaire RAG (ChromaDB + Mistral, modèle choisi par `MISTRAL_MODEL`), avec validation obligatoire par un médecin.

Dans Korai, ce service est appelé **uniquement par le backend Korai**, avec le jeton partagé `SERVICE_API_TOKEN` (voir `backend/.env.example`).

Ce dossier rassemble le frontend de `Version5` et le backend de `Version4`, sans les fichiers obsolètes, avec les corrections listées dans [AMELIORATIONS.md](AMELIORATIONS.md). Les dossiers `Version4` et `Version5` n'ont pas été modifiés.

## Structure

```
VersionFinale/
├── docker-compose.yml        # lancement complet (frontend nginx + backend)
├── .gitignore                # exclut secrets, données patients, modèles, bases
├── frontend/                 # React + TypeScript + Vite + Tailwind
│   ├── src/                  # App.tsx, shared.ts (client API), supabase.ts, components/
│   ├── Dockerfile, nginx.conf
│   └── .env.example
└── backend/                  # FastAPI
    ├── utils/
    │   ├── rag_api.py              # application FastAPI (toutes les routes)
    │   ├── orl_Inference_pipeline.py  # prétraitement + inférence ONNX + top-3
    │   ├── pdf_processor.py        # indexation des PDF dans ChromaDB
    │   └── checkpoints/*.pth       # poids PyTorch d'origine (non versionnés)
    ├── efficientnet.onnx (+ .data) # modèle servi (non versionné)
    ├── KORAI-APP/chroma_db/        # base vectorielle, 44 430 chunks (non versionnée)
    ├── scripts/                    # diagnose_vision.py, compare_vision.py, benchmark_latency.py
    ├── evaluation/                 # résultats de référence (diagnosis/, results/)
    ├── setup_drive.py              # obtention du jeton Google Drive (une seule fois)
    ├── requirements.txt, Dockerfile, rag_api.spec
    └── .env.example
```

## Fichiers non versionnés (à transmettre hors Git)

| Fichier | Taille | Où le trouver |
|---|---|---|
| `backend/efficientnet.onnx` + `.onnx.data` | 16 Mo | déjà copiés ici ; sinon `Version4/backend/` |
| `backend/KORAI-APP/chroma_db/` | 337 Mo | déjà copiée ici ; ou à reconstruire avec `pdf_processor.py` |
| `backend/utils/checkpoints/best_efficientNetB0_final_all_ds.pth` | 16 Mo | déjà copié ici |
| `backend/test_set/` (45 images patients) | 2 Mo | **non copié** : `Version4/backend/test_set/`, à placer ici seulement pour les évaluations |
| Corpus PDF (23 documents) | — | poste de l'auteur de la base (à demander) ; à indiquer avec `--pdf-folder` pour réindexer |
| `backend/.env` | — | à créer depuis `.env.example`, avec vos propres clés |

À partager via un espace de stockage de l'entreprise (ou Git LFS pour les modèles), jamais par e-mail.

## Lancer en développement

**Backend** (Python 3.11) :

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate            # Linux/macOS : source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env            # puis renseigner MISTRAL_API_KEY
python -m uvicorn utils.rag_api:app --host 127.0.0.1 --port 8000
```

La commande doit être lancée depuis `backend/`. Au premier démarrage, le modèle `intfloat/multilingual-e5-base` est téléchargé depuis Hugging Face. Vérification : `http://localhost:8000/health`, documentation interactive : `http://localhost:8000/docs`.

**Frontend** (Node 20) :

```bash
cd frontend
npm install
npm run dev                       # http://localhost:5173
```

Le proxy Vite (`vite.config.ts`) redirige `/api/*` vers `http://localhost:8000`. Aucun compte n'est pré-rempli : les comptes de démonstration sont définis dans `src/shared.ts` (`DEFAULT_USERS`) et doivent être changés.

## Lancer avec Docker

```bash
copy backend\.env.example backend\.env   # renseigner MISTRAL_API_KEY
docker compose up -d --build
```

Interface : `http://localhost:8080`. Le backend n'est pas exposé directement ; nginx lui transmet les appels `/api/`.

## Opérations courantes

| Besoin | Commande / fichier |
|---|---|
| Lancer les tests de l'API (sans Mistral ni modèles) | `.venv/bin/python -m unittest discover -s tests -t . -v` |
| Réindexer le corpus | `python utils/pdf_processor.py --pdf-folder <dossier_pdf> --reset` |
| Évaluer le modèle de vision | placer `test_set/` dans `backend/`, puis `python scripts/diagnose_vision.py` → `evaluation/diagnosis/` |
| Comparer PyTorch et ONNX | `python scripts/compare_vision.py` → `evaluation/model_comparison.csv` |
| Mesurer les latences | `python scripts/benchmark_latency.py` → `evaluation/latency_real.csv` |
| Obtenir le jeton Google Drive | placer `client_secret.json` dans `backend/`, puis `python setup_drive.py` |
| Modifier les consignes du LLM | `_CONSULTATION_PROMPT`, `_DOCTOR_PROMPT` dans `utils/rag_api.py` |
| Changer le modèle de vision | remplacer `efficientnet.onnx`, mettre à jour `class_names` (pipeline), `CLASS_KEYWORDS` (rag_api) et `PATHOLOGIES` (DatasetCollection.tsx) dans le même ordre |

## Publier sur GitHub / GitLab

1. Ne jamais versionner ni transmettre les fichiers `.env`, `client_secret.json` ou les archives des anciennes versions (`backend.tar.gz` contient des clés). Si une clé est exposée par erreur, la révoquer immédiatement dans la console du service concerné.
2. Dépôt **privé**, dans l'organisation de l'entreprise, 2FA activée, branche `main` protégée.
3. Avant le premier push :

```bash
git init
git add .
git status                        # vérifier : aucun .env, .onnx, chroma_db, test_set
gitleaks detect --source .        # détection de secrets (https://github.com/gitleaks/gitleaks)
git commit -m "KORAI ORL - version finale"
git remote add origin <url-du-depot-prive>
git push -u origin main
```

## Limites connues

Voir la section « Limites » d'AMELIORATIONS.md : l'interface web n'a pas d'authentification réelle (et ne peut plus appeler l'API quand `SERVICE_API_TOKEN` est défini), cas stockés en mémoire côté backend, données patients transmises à un LLM externe (sans nom ni prénom), aucune classe de rejet (une image hors sujet reçoit quand même une des 10 classes, parfois avec 100 % de confiance).
