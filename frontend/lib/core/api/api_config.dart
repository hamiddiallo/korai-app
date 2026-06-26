import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  /// Override au build (prioritaire), utile en CI/CD :
  /// `--dart-define=KORAI_API_URL=...`
  static const _compileTimeUrl = String.fromEnvironment('KORAI_API_URL');

  /// URL de base de l'API Korai (backend Node.js, port 4000 par defaut).
  ///
  /// Le service IA FastAPI (URL ngrok dans `backend/.env` → `AI_SERVICE_BASE_URL`)
  /// est joignable uniquement via ce backend :
  /// - `POST /ai/chat` → FastAPI `/chat`
  /// - `POST /ai/rag/analyze` → FastAPI `/rag/analyze`
  /// - `POST /cases/diagnose` + fichier → `/diagnose-separate` (image anonymisee)
  /// - `POST /cases/diagnose` sans fichier → `/rag/analyze` (symptomes seuls)
  ///
  /// Priorite de resolution :
  ///  1. `--dart-define=KORAI_API_URL=...` (override au build).
  ///  2. Cle `KORAI_API_URL` du fichier `.env` charge au demarrage
  ///     (cf. `main.dart` / `.env.example`).
  ///  3. Heuristique plateforme (valeurs de dev local) :
  ///     Android emulateur `10.0.2.2:4000` | iOS sim/web `127.0.0.1:4000`.
  ///     Appareil physique : IP du Mac (ex. `http://192.168.1.12:4000`).
  ///     Production : renseigner `KORAI_API_URL=https://...` dans `.env`.
  static String get baseUrl {
    if (_compileTimeUrl.isNotEmpty) return _compileTimeUrl;

    final envUrl = dotenv.isInitialized ? dotenv.maybeGet('KORAI_API_URL') : null;
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) return 'http://127.0.0.1:4000';
    if (Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://127.0.0.1:4000';
  }
}
