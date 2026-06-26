# Korai ORL

Application mobile intelligente pour consultations ORL en soins primaires.


## Structure

- `frontend/`: application Flutter.
- `backend/`: API Node.js TypeScript.

## Priorites implementees

- Authentification backend avec JWT et gestion des roles.
- Persistance backend avec Prisma + PostgreSQL (ou SQLite en dev minimal).
- Inscription patient, infirmier (compte en attente lie a un matricule) et specialiste (auto-actif) ; validation des inscriptions par l'expert/admin.
- Registre Medecin et statuts de compte (ACTIVE / PENDING / REJECTED).
- Profil admin : gestion des comptes, patients, referentiels cliniques et registre Medecin.
- Creation de cas ORL avec image + symptomes ; niveau d'urgence calcule automatiquement.
- Proxy backend vers l'API IA FastAPI (URL ngrok `AI_SERVICE_BASE_URL`) : chat, RAG, diagnose-separate, avec anonymisation de l'image.
- Gestion des echecs IA (codes typés) et reutilisation d'un diagnostic equivalent.
- Tele-expertise : demande cote infirmier, espace specialiste (prise en charge + avis).
- Mode hors-ligne (Flutter) : stockage local chiffre (SQLCipher), file de synchronisation avec reprise des echecs, deduplication IA hors connexion.
- Notifications in-app (cloche + polling) pour infirmier, specialiste et patient.

## Lancement backend

```bash
cd backend
cp .env.example .env
npm install
npm run db:push
npm run dev
```

## Lancement mobile

```bash
cd frontend
cp .env.example .env   # configurer KORAI_API_URL (URL du backend)
flutter pub get
flutter run            # le .env est lu automatiquement, aucun flag requis
```

Voir `frontend/README.md` pour le detail des valeurs de `KORAI_API_URL` selon la cible (emulateur, appareil physique, production).

Validations effectuees:

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build ios --simulator`
