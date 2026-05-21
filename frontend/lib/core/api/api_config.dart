import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static const _envUrl = String.fromEnvironment('KORAI_API_URL');

  /// URL de l'API Korai.
  ///
  /// Priorite: `--dart-define=KORAI_API_URL=...` puis heuristique plateforme.
  /// Sur iPhone physique, utiliser l'IP du Mac (ex. `http://192.168.1.12:4000`).
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (kIsWeb) return 'http://127.0.0.1:4000';
    if (Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://127.0.0.1:4000';
  }
}
