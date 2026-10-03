import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';

/// Fichier d'un envoi multipart : une photo de tympan et son champ (fileRight, fileLeft…).
class MultipartUpload {
  const MultipartUpload({required this.field, required this.bytes, required this.fileName, required this.mimeType});

  final String field;
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  /// Session invalide ou expirée (401) : il faut se reconnecter. Un refus 403
  /// (dossier hors périmètre, accord manquant…) ne concerne que la requête.
  bool get isAuthFailure => statusCode == 401;

  /// Le serveur a déjà reçu la même création (envoi en double) : le prochain
  /// essai renvoie l'élément existant.
  bool get isAlreadyReceived => statusCode == 409 && code == 'CONFLICT';

  /// Échec réseau côté client (pas de connexion / hôte injoignable / timeout
  /// local) : aucune réponse du serveur. Toujours retryable.
  bool get isNetworkFailure => code == 'NETWORK';

  /// Le service IA (en aval du backend) est indisponible : timeout, injoignable
  /// ou erreur 5xx. Retryable, à distinguer d'un refus métier.
  bool get isAiUnavailable => code == 'AI_TIMEOUT' || code == 'AI_UNREACHABLE' || code == 'AI_SERVICE_ERROR';

  bool get isAiTimeout => code == 'AI_TIMEOUT';

  /// 4xx définitif (hors 408/429) ET hors échec réseau : le serveur a refusé,
  /// rejouer à l'identique ne sert à rien.
  bool get isPermanentClientFailure =>
      statusCode != null &&
      statusCode! >= 400 &&
      statusCode! < 500 &&
      statusCode != 408 &&
      statusCode != 429 &&
      !isAlreadyReceived;

  @override
  String toString() => message;
}

/// Type MIME d'une photo d'après son extension (JPEG par défaut : c'est le
/// format produit par la prise de vue et les retouches de l'application).
/// Format réel d'une photo d'après son contenu (signature), pas son nom :
/// le serveur refuse une photo dont le type déclaré ne correspond pas.
String sniffImageMimeType(List<int> bytes) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'image/png';
  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) && startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

/// Délai max d'une requête ; généreux pour couvrir le proxy IA (~120 s backend).
const _requestTimeout = Duration(seconds: 150);

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String? _accessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// Renouvelle le jeton d'accès expiré (fourni par la session). Renvoie
  /// `true` si un nouveau jeton est posé, `false` si la session est terminée ;
  /// lève une erreur `NETWORK` si le serveur est injoignable.
  Future<bool> Function()? tokenRefresher;

  /// Appelé une fois quand la session ne peut pas être renouvelée.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  static const _noRefreshPaths = ['/auth/login', '/auth/refresh', '/auth/register'];

  /// Un seul renouvellement à la fois, partagé par les requêtes parallèles.
  Future<bool> _refreshSession() {
    return _refreshing ??= () async {
      try {
        final ok = await tokenRefresher!();
        if (!ok) onSessionExpired?.call();
        return ok;
      } finally {
        _refreshing = null;
      }
    }();
  }

  /// Exécute la requête ; sur « jeton expiré » (401), renouvelle la session
  /// puis rejoue la requête une fois avec le nouveau jeton.
  Future<T> _send<T>(String path, Future<T> Function() operation) async {
    try {
      return await _guardNetwork(operation);
    } on ApiException catch (e) {
      final canRefresh = e.statusCode == 401 &&
          e.code == 'UNAUTHORIZED' &&
          _accessToken != null &&
          tokenRefresher != null &&
          !_noRefreshPaths.any(path.startsWith);
      if (!canRefresh) rethrow;
      if (!await _refreshSession()) {
        throw ApiException(
          'Votre session a expiré. Reconnectez-vous pour continuer.',
          code: 'SESSION_EXPIRED',
          statusCode: 401,
        );
      }
      return _guardNetwork(operation);
    }
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Exécute une opération réseau et traduit toute panne de transport
  /// (hors-ligne, hôte injoignable, timeout local) en [ApiException] typée
  /// `NETWORK`, plutôt que de laisser fuiter une exception brute non gérée.
  Future<T> _guardNetwork<T>(Future<T> Function() operation) async {
    try {
      return await operation().timeout(_requestTimeout);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException(
        // Message neutre : il sert aussi aux lectures. Les actions enregistrées
        // hors ligne (soignant) affichent leur propre message de synchronisation.
        'Serveur injoignable. Vérifiez votre connexion internet, puis réessayez.',
        code: 'NETWORK',
      );
    } on http.ClientException {
      throw ApiException(
        'Connexion au serveur impossible. Vérifiez votre réseau, puis réessayez.',
        code: 'NETWORK',
      );
    } on TimeoutException {
      throw ApiException(
        'Le serveur met trop de temps à répondre. Réessayez dans un instant.',
        code: 'NETWORK',
      );
    }
  }

  /// Contenu binaire protégé (photo du tympan) : même authentification et
  /// même renouvellement de session que les requêtes JSON.
  Future<Uint8List> getBytes(String path) {
    return _send(path, () async {
      final response = await _httpClient.get(_uri(path), headers: {..._headers, 'Accept': '*/*'});
      if (response.statusCode >= 400) _decode(response); // lève l'erreur typée du serveur
      return response.bodyBytes;
    });
  }

  Future<Map<String, dynamic>> getJson(String path) {
    return _send(path, () async {
      final response = await _httpClient.get(_uri(path), headers: _headers);
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) {
    return _send(path, () async {
      final response = await _httpClient.post(
        _uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body) {
    return _send(path, () async {
      final response = await _httpClient.patch(
        _uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> deleteJson(String path) {
    return _send(path, () async {
      final response = await _httpClient.delete(_uri(path), headers: _headers);
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> postMultipart({
    required String path,
    required Map<String, String> fields,
    required File file,
    required String fileField,
  }) async {
    return _send(path, () async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers);
      request.fields.addAll(fields);
      // Type explicite, lu dans le contenu du fichier : sans lui, `fromPath`
      // envoie application/octet-stream, et un type qui ne correspond pas au
      // contenu est refusé par le serveur (JPEG, PNG ou WebP attendus).
      final head = await file.openRead(0, 16).expand((chunk) => chunk).toList();
      request.files.add(
        await http.MultipartFile.fromPath(fileField, file.path, contentType: MediaType.parse(sniffImageMimeType(head))),
      );

      final streamed = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    });
  }

  /// Envoi multipart de plusieurs fichiers : une photo par oreille (fileRight, fileLeft).
  Future<Map<String, dynamic>> postMultipartUploads({
    required String path,
    required Map<String, String> fields,
    required List<MultipartUpload> uploads,
  }) async {
    return _send(path, () async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers);
      request.fields.addAll(fields);
      for (final upload in uploads) {
        request.files.add(
          http.MultipartFile.fromBytes(
            upload.field,
            upload.bytes,
            filename: upload.fileName,
            contentType: MediaType.parse(upload.mimeType),
          ),
        );
      }
      final streamed = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> postMultipartBytes({
    required String path,
    required Map<String, String> fields,
    required Uint8List bytes,
    required String fileName,
    required String fileField,
    String mimeType = 'image/jpeg',
  }) async {
    return _send(path, () async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers);
      request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final streamed = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    });
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      // Corps non-JSON : 4xx/5xx → service indisponible ; 2xx (ex. page d'un
      // portail captif/proxy renvoyée en 200) → traité comme panne réseau pour
      // que la gestion hors-ligne (isNetworkFailure) s'applique au lieu de
      // laisser fuiter une FormatException non gérée.
      throw ApiException(
        response.statusCode >= 400
            ? 'Le service est temporairement indisponible. Veuillez réessayer plus tard.'
            : 'Réponse inattendue du serveur. Vérifiez votre connexion, puis réessayez.',
        code: response.statusCode >= 400 ? null : 'NETWORK',
        statusCode: response.statusCode >= 400 ? response.statusCode : null,
      );
    }

    if (response.statusCode >= 400) {
      final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
      if (error is Map<String, dynamic>) {
        final code = error['code']?.toString();
        final friendly = _friendlyAiMessage(code);
        throw ApiException(
          friendly ?? error['message']?.toString() ?? 'Erreur API',
          code: code,
          statusCode: response.statusCode,
        );
      }
      throw ApiException(
        'Erreur API ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    return decoded as Map<String, dynamic>;
  }

  /// Message clair et orienté action pour chaque code d'erreur IA du backend.
  String? _friendlyAiMessage(String? code) {
    switch (code) {
      case 'AI_TIMEOUT':
        return "L'analyse IA met trop de temps à répondre. La consultation est enregistrée ; vous pouvez relancer l'analyse.";
      case 'AI_UNREACHABLE':
      case 'AI_SERVICE_ERROR':
        return "Le service d'analyse IA est momentanément indisponible. La consultation est enregistrée ; l'analyse sera relançable.";
      case 'AI_BAD_REQUEST':
        return "L'analyse IA n'a pas pu traiter cette consultation. Vérifiez les informations saisies.";
      default:
        return null;
    }
  }
}
