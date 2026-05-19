# Korai Frontend

Application Flutter mobile pour les trois roles du systeme Korai ORL.

## Demarrage

```bash
flutter pub get
flutter run --dart-define=KORAI_API_URL=http://localhost:4000
```

Si `flutter` n'est pas encore dans le `PATH` de ce poste:

```bash
export PATH="$PATH:/Users/hamid/Downloads/develop/flutter/bin"
```

Sur emulateur Android, remplacer souvent `localhost` par `10.0.2.2`:

```bash
flutter run --dart-define=KORAI_API_URL=http://10.0.2.2:4000
```

## Etat de l'environnement mobile

`flutter doctor -v` confirme que Flutter 3.41.9, Dart 3.11.5, Android SDK, Xcode et CocoaPods sont installes pour le developpement mobile.

Validations effectuees:

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug --dart-define=KORAI_API_URL=http://10.0.2.2:4000`
- `flutter build ios --simulator --dart-define=KORAI_API_URL=http://localhost:4000`

Chrome reste optionnel et seulement utile pour une cible Flutter Web.

## Parcours MVP actuel

- Connexion professionnelle.
- Routage par role vers l'espace admin ou infirmier.
- Espace admin pour comptes, patients, symptomes, antecedents et verifications au toucher.
- Espace infirmier.
- Flux infirmier structure en MVVM leger avec `NurseConsultationViewModel`.
- Creation rapide d'un dossier patient.
- Capture image via camera.
- Saisie symptomes et signes cliniques.
- Appel backend `POST /cases/diagnose`.
- Affichage organise des avis IA image et symptomes/RAG.

## Prochaines etapes frontend

- Ajouter le stockage local chiffre pour le mode offline-first.
- Migrer progressivement les ViewModels vers Riverpod ou Bloc si les workflows deviennent plus complexes.
- Ajouter les ecrans specialiste et patient.
- Ajouter la visionneuse image avec zoom/annotation.
