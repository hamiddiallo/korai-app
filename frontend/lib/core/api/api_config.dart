import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static const _envUrl = String.fromEnvironment('KORAI_API_URL');

  /// URL de l'API Korai (backend Node.js, port 4000 par defaut).
  ///
  /// Le service IA FastAPI (URL ngrok dans `backend/.env` → `AI_SERVICE_BASE_URL`)
  /// est joignable uniquement via ce backend :
  /// - `POST /ai/chat` → FastAPI `/chat`
  /// - `POST /ai/rag/analyze` → FastAPI `/rag/analyze`
  /// - `POST /cases/diagnose` + fichier → `/diagnose-separate` (image anonymisee)
  /// - `POST /cases/diagnose` sans fichier → `/rag/analyze` (symptomes seuls)
  ///
  /// Priorite: `--dart-define=KORAI_API_URL=...` puis heuristique plateforme.
  /// Android emulateur : `10.0.2.2:4000` | iOS simulateur : `127.0.0.1:4000`
  /// Appareil physique : IP du Mac (ex. `http://192.168.1.12:4000`).
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (kIsWeb) return 'http://127.0.0.1:4000';
    if (Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://127.0.0.1:4000';
  }
}
