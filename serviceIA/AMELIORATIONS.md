# Améliorations apportées dans VersionFinale

Toutes les modifications ont été faites sur des copies ; `Version4` et `Version5` sont inchangés.

## Contenu retenu / écarté

| Retenu | Écarté (reste dans Version4/Version5) |
|---|---|
| Frontend `Version5` complet (src + configuration Vite, TS, Tailwind, ESLint, Dockerfile, nginx) | `node_modules`, `front.zip`, `fix_encoding.py`, `generate_rapport.py`, rapports .md/.docx, `DEPLOYMENT.md` |
| `utils/rag_api.py`, `orl_Inference_pipeline.py`, `pdf_processor.py` | `main.py`, `routes/` (squelette non fonctionnel), `rag_context.py`, `mistral_client.py`, `korai.db` (vides ou inutilisés) |
| Modèle ONNX, checkpoint .pth, base `KORAI-APP/chroma_db` | ancienne base `utils/chroma_db`, `Version5/backend` (copie plus ancienne du backend) |
| `diagnose_vision.py`, `compare_vision.py`, `benchmark_latency.py` → `scripts/` | `evaluate_vision*.py` (remplacés par diagnose_vision), `verify-onnx.py`, `export_onnx.py` (obsolète), `debug_imports.py`, `diagnose_chromadb.py`, `check_*.py` |
| Résultats de référence `diagnosis/`, `results/` → `evaluation/` | `old_results/`, `results_new/` (mesures faussées par le bug d'ordre des classes), figures de thèse et de soutenance |
| `setup_drive.py` (portée Drive minimale `drive.file`) | `generate_drive_token.py` (portée Drive complète) |
| — | `.env`, `client_secret.json`, `backend.tar.gz` (secrets), `test_set/` (images patients) |

## Sécurité et confidentialité

- `.gitignore`, `.dockerignore` (backend et frontend) : secrets, données patients, modèles et bases exclus de Git et des images Docker.
- `.env.example` (backend et frontend) : variables documentées, sans valeurs.
- Images Google Drive **privées par défaut** : le partage public n'a lieu que si `GOOGLE_DRIVE_PUBLIC_LINKS=true` (`rag_api.py`).
- CORS configurable par `ALLOWED_ORIGINS` (défaut : `http://localhost:5173`) au lieu de `*`.
- Le nom et le prénom du patient ne sont plus envoyés au LLM ; seuls l'âge, le sexe et les données cliniques le sont (`NewConsultation.tsx`).
- L'écran de connexion n'est plus pré-rempli avec un mot de passe (`Login.tsx`).

## Corrections fonctionnelles

- **Analyse sans image** : appelait `/chat/simple` (prompt « médecin ») et lisait un champ `response` inexistant ; utilise désormais `/rag/analyze` (prompt « consultation » structuré) et son champ `summary`.
- **Deux oreilles** : le RAG était exécuté deux fois ; la seconde image passe maintenant par `/vision/predict`.
- **Mode hors ligne** : les prédictions aléatoires ont été supprimées ; un message « Analyse IA indisponible » s'affiche et la consultation peut être conclue avec le seul diagnostic de l'expert.
- **Validation** : le frontend transmet l'identité de l'expert, les jugements séparés vision / RAG et les motifs ; le backend les enregistre dans le cas et dans l'export JSON.
- **Softmax** stabilisé (soustraction du maximum des logits) : plus de NaN sur des entrées extrêmes. Vérifié : même résultat qu'avant sur une image du jeu de test (otite moyenne aiguë, 96,8 %).
- Erreur TypeScript préexistante corrigée (type `page` des sources) : `tsc --noEmit` passe sans erreur.

## Outillage

- `requirements.txt` unique (base Docker/Linux) + paquets manquants : `pypdf` (indexation), `google-auth-oauthlib` (setup_drive).
- Scripts d'évaluation : chemins relatifs au dossier `backend/` au lieu de chemins Windows absolus ; `compare_vision.py` utilise l'ordre des classes du pipeline (corrige l'ancien bug) ; `benchmark_latency.py` pointe vers le bon modèle.
- `rag_api.spec` (PyInstaller) : chemin du modèle corrigé.
- `docker-compose.yml` : frontend nginx sur le port 8080, backend interne, cache Hugging Face persistant.
- `README.md` : installation, lancement, opérations courantes, publication Git.

## Intégration avec Korai et durcissement (03/10/2026)

- **Jeton partagé** `SERVICE_API_TOKEN` : exigé sur toutes les routes sauf `/`, `/health` et `/docs`, et vérifié avant la lecture du corps de la requête. Sans le jeton, impossible de lancer une analyse, de lire `/cases` ou d'exporter les cas. Le backend Korai l'envoie (`AI_SERVICE_API_KEY`). Laissé vide, le service reste ouvert : réservé au développement sur `127.0.0.1`.
- **Modèle Mistral configurable** : `MISTRAL_MODEL`, avec le délai `MISTRAL_TIMEOUT_S` et le nombre de nouvelles tentatives `MISTRAL_MAX_RETRIES`. L'abonnement actuel refuse `mistral-large-latest` et limite Medium et Small à 0 requête par minute ; `ministral-14b-latest` est donc utilisé.
- **Analyses dans des threads** : un appel à Mistral ne bloque plus le serveur. Avant, il traitait une requête à la fois, `/health` compris.
- **Réponse partielle** : si Mistral échoue, `/diagnose-separate` renvoie quand même la prédiction de l'image (`rag: null`, `rag_error`).
- **Erreurs neutres** : les réponses ne contiennent plus de détail technique (`str(e)`). Les journaux n'enregistrent plus le texte des questions, et la télémétrie ChromaDB est coupée.
- **Recherche documentaire** : la question était encodée « passage: query: … » (mauvais préfixe E5), elle l'est maintenant « query: … ». Les documents retrouvés diffèrent donc de ceux des évaluations précédentes.
- **Sources** : le nom du document s'affiche sans le chemin Windows du poste d'indexation. La page indiquée est la page imprimée (`page_label`, sinon la numérotation à partir de 1).
- **Longueur des réponses** : jusqu'à 1 500 jetons. À 1 000, elles étaient coupées en pleine phrase.
- **Images** : 10 Mo maximum (`MAX_UPLOAD_MB`). Une image illisible est refusée (erreur 400), et le nom de fichier du jeu de données ne peut plus désigner un autre dossier.
- **Mémoire bornée** : nombre de cas gardés limité par `CASE_HISTORY_SIZE` (0 = aucun), conversations limitées à 200.
- **`/app`** ne sert plus que `frontend/dist`. Il servait auparavant les sources, dont `shared.ts`.
- **Dépendances** : FastAPI 0.141.1 et Starlette 1.7.0, qui corrigent les failles de Starlette 0.27. Le démarrage passe par `lifespan`.
- **Tests** : `tests/test_api.py`, 16 tests sans Mistral ni modèles. Lancer : `.venv/bin/python -m unittest discover -s tests -t . -v`.

## Limites restantes (non traitées)

- Interface web (`frontend/`) : comptes et mots de passe stockés dans le navigateur. Avec `SERVICE_API_TOKEN` défini, elle ne peut plus appeler l'API, car le jeton ne doit jamais être placé dans le frontend : à n'utiliser qu'en développement, avec un jeton vide.
- Cas et conversations en mémoire côté backend (bornés, perdus au redémarrage).
- Pas de classe de rejet ni de seuil de confiance : du bruit aléatoire est classé avec jusqu'à 100 % de confiance.
- Tableau de bord partiellement alimenté par des valeurs fixes (`Dashboard.tsx`).
- Aucun test automatisé du frontend.
- Classe `Chroma` de `langchain_community` dépréciée (avertissement au démarrage) : passer à `langchain-chroma`.
- Le build Vite n'a pas pu être exécuté pendant la préparation (binaire natif Windows de rollup) : lancer `npm install` puis `npm run build` pour le vérifier.
