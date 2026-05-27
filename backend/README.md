# Korai Backend

API Node.js TypeScript pour l'authentification, les roles, les patients, les cas ORL et l'orchestration vers l'API IA.

## Demarrage

```bash
cp .env.example .env
# Editer .env : coller l'URL ngrok du service FastAPI dans AI_SERVICE_BASE_URL
npm install
npm run db:push
npm run dev
```

### Service IA (ngrok)

Le backend ne contacte **pas** `localhost:8000`. Il proxy vers l'URL definie dans `.env` :

```env
AI_SERVICE_BASE_URL=https://votre-tunnel.ngrok-free.app
```

Au demarrage, l'URL configuree est affichee dans les logs. Routes proxy :

| Korai backend | FastAPI (ngrok) |
|---------------|-----------------|
| `POST /ai/chat` | `POST /chat` |
| `POST /ai/rag/analyze` | `POST /rag/analyze` |
| `POST /cases/diagnose` (avec `file`) | `POST /diagnose-separate` |
| `POST /cases/diagnose` (sans `file`) | `POST /rag/analyze` |

Comptes de demonstration crees au demarrage:

- Infirmier: `nurse@korai.local` / `Password123!`
- Specialiste: `orl@korai.local` / `Password123!`
- Admin: `admin@korai.local` / `Password123!`

## Routes principales

- `POST /auth/login`
- `POST /auth/register/patient`
- `POST /auth/register/nurse`
- `POST /auth/register` reserve au role `ADMIN`
- `GET|POST|PATCH|DELETE /admin/users`
- `GET|PATCH|DELETE /admin/patients`
- `GET|POST|PATCH|DELETE /admin/clinical-items`
- `GET /auth/me`
- `GET /patients`
- `POST /patients`
- `GET /cases`
- `POST /cases/diagnose` en `multipart/form-data`
- `POST /cases/:id/request-specialist-review`
- `POST /cases/:id/specialist-review`
- `GET|POST /chat/conversations`
- `GET|PATCH /chat/conversations/:id`
- `GET|POST /chat/conversations/:id/messages`
- `POST /chat/conversations/:id/messages/:messageId/retry`
- `PATCH /chat/conversations/:id/read`

## Creation de compte

Inscription patient:

```bash
curl -X POST http://localhost:4000/auth/register/patient \
  -H 'Content-Type: application/json' \
  -d '{
    "firstName": "Awa",
    "lastName": "Diop",
    "email": "awa.diop@example.com",
    "password": "Password123!",
    "phone": "771234567",
    "sex": "F",
    "consentForAi": true,
    "consentForTeleExpertise": true
  }'
```

Inscription infirmier:

```bash
curl -X POST http://localhost:4000/auth/register/nurse \
  -H 'Content-Type: application/json' \
  -d '{
    "fullName": "Moussa Ndiaye",
    "email": "moussa.ndiaye@example.com",
    "password": "Password123!",
    "phone": "771112233",
    "healthFacility": "Poste de sante de Thies",
    "professionalId": "INF-TH-001"
  }'
```

## Persistence

Le backend utilise Prisma. L'environnement local courant pointe vers PostgreSQL via `DATABASE_URL`.

- Schema: `prisma/schema.prisma`
- Base locale: definie par `DATABASE_URL` dans `backend/.env`
- Synchronisation schema local: `npm run db:push`

Commandes utiles:

```bash
npm run db:push
npm run db:status
npm run db:studio
```

Pour un environnement de demonstration simple, il reste possible d'utiliser SQLite en adaptant le provider Prisma et `DATABASE_URL`, mais la cible projet recommandee reste PostgreSQL.
