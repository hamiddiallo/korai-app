# Korai ORL

Application mobile intelligente pour consultations ORL en soins primaires.

Voir [PROJET_REPERE.md](/Users/hamid/Downloads/Korai-app/PROJET_REPERE.md) pour l'architecture, les bonnes pratiques et la feuille de route.

## Structure

- `frontend/`: application Flutter.
- `backend/`: API Node.js TypeScript.

## Priorites implementees

- Authentification backend avec JWT.
- Gestion des roles.
- Persistance backend avec Prisma + PostgreSQL (ou SQLite en dev minimal).
- Creation de compte patient et infirmier via routes dediees.
- Profil admin avec gestion des comptes, patients et referentiels cliniques.
- Creation de patient cote infirmier.
- Creation de cas ORL avec image + symptomes.
- Proxy backend vers l'API IA FastAPI (URL ngrok `AI_SERVICE_BASE_URL`) : chat, RAG, diagnose-separate.
- Organisation de la reponse IA en synthese exploitable.
- Flux infirmier Flutter refactore en MVVM leger avec ViewModel.

## Lancement backend

```bash
cd backend
cp .env.example .env
npm install
npm run db:push
npm run dev
```

## Etat mobile

Flutter 3.41.9 et Dart 3.11.5 sont detectes via `/Users/hamid/Downloads/develop/flutter/bin`.

Validations effectuees:

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build ios --simulator`
