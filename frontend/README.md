# Korai Frontend

Application Flutter mobile de Korai ORL — aide à la consultation ORL, télé-expertise et mode hors-ligne — pour les profils soignant, spécialiste, patient et administrateur.

## Démarrage

1. Configurer l'URL du backend (une seule fois) :

```bash
cp .env.example .env
# puis ajuster KORAI_API_URL dans .env selon la cible
```

2. Lancer l'app — le `.env` est lu automatiquement au démarrage (flutter_dotenv), **aucun flag requis** :

```bash
flutter pub get
flutter run
```

Si `flutter` n'est pas dans le `PATH` :

```bash
export PATH="$PATH:/chemin/vers/flutter/bin"
```

### Choix de l'URL backend (`KORAI_API_URL`)

| Cible | Valeur |
|-------|--------|
| Émulateur Android | `http://10.0.2.2:4000` |
| Simulateur iOS / Web | `http://127.0.0.1:4000` |
| Appareil physique | `http://<IP-LAN-de-la-machine>:4000` |
| Production | `https://api.votre-domaine.com` |

> Le `.env` réel est **gitignoré** ; seul `.env.example` est versionné. Comme il est embarqué dans l'app, n'y mettez **que de la config non sensible** (l'URL) — jamais de secret.

### Comment l'URL est résolue (ordre de priorité)

`ApiConfig.baseUrl` cherche `KORAI_API_URL` dans cet ordre, et prend **la première valeur trouvée** :

1. `--dart-define=KORAI_API_URL=...` passé à la commande de build *(prioritaire)* ;
2. la clé `KORAI_API_URL` du fichier **`.env`** *(cas normal)* ;
3. à défaut, une valeur par défaut selon la plateforme (dev local).

En usage quotidien, **le `.env` suffit** : tu n'as rien d'autre à faire.

### Override ponctuel via `--dart-define` (optionnel)

`--dart-define` injecte l'URL **au moment du build** et **écrase** la valeur du `.env`,
mais **seulement pour cette commande-là** (le `.env` n'est pas modifié). Deux usages :

- **Test rapide** contre un autre serveur sans toucher à ton `.env` :

  ```bash
  flutter run --dart-define=KORAI_API_URL=https://api.example.com
  ```

- **CI/CD** : sur une machine d'intégration il n'y a pas de `.env` (gitignoré) ;
  le pipeline passe alors l'URL directement dans la commande de build :

  ```bash
  flutter build apk --release --dart-define=KORAI_API_URL=https://api.korai.sn
  ```

| Méthode | Pour qui | Persistant ? |
|---------|----------|--------------|
| `.env` | développeur au quotidien | oui (jusqu'à modification du fichier) |
| `--dart-define` | test ponctuel / build CI/CD | non (ce build uniquement), **prioritaire** |

## Validations

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Fonctionnalités principales

- **Connexion / inscription** professionnelle (infirmier, spécialiste) et routage par rôle.
- **Espace soignant** : dossiers patients, consultation ORL guidée (symptômes, antécédents, toucher, image), appel IA `POST /cases/diagnose`, niveau d'urgence calculé automatiquement.
- **Mode hors-ligne** : stockage local chiffré (SQLCipher), file de synchronisation (outbox) avec reprise et panneau des échecs, réutilisation d'un diagnostic IA équivalent hors connexion.
- **Télé-expertise** : envoi des cas complexes au spécialiste ; espace spécialiste (prise en charge, avis).
- **Espace patient** : pré-consultation et comptes-rendus.
- **Espace admin** : comptes, patients, référentiels cliniques, validation des inscriptions.
- **Notifications** in-app (cloche + polling) pour soignant, spécialiste et patient.
- **Assistant éducatif ORL** (chatbot).

## Prochaines étapes

- Interaction vocale (mains libres) pendant la consultation.
- Proposition et gestion d'ordonnances + rappels de prise de médicament.
- Visionneuse image avec zoom / annotation.
