import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  /// Échec réseau côté client (pas de connexion / hôte injoignable / timeout
  /// local) : aucune réponse du serveur. Toujours retryable.
  bool get isNetworkFailure => code == 'NETWORK';

  /// Le service IA (en aval du backend) est indisponible : timeout, injoignable
  /// ou erreur 5xx. Retryable, à distinguer d'un refus métier.
  bool get isAiUnavailable =>
      code == 'AI_TIMEOUT' ||
      code == 'AI_UNREACHABLE' ||
      code == 'AI_SERVICE_ERROR';

  bool get isAiTimeout => code == 'AI_TIMEOUT';

  /// 4xx définitif (hors 408/429) ET hors échec réseau : le serveur a refusé,
  /// rejouer à l'identique ne sert à rien.
  bool get isPermanentClientFailure =>
      statusCode != null &&
      statusCode! >= 400 &&
      statusCode! < 500 &&
      statusCode != 408 &&
      statusCode != 429;

  @override
  String toString() => message;
}

/// Délai max d'une requête ; généreux pour couvrir le proxy IA (~120 s backend).
const _requestTimeout = Duration(seconds: 150);

class ApiClient {
  ApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String? _accessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
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
        'Pas de connexion internet. L\'action sera synchronisée au retour du réseau.',
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

  Future<Map<String, dynamic>> getJson(String path) {
    return _guardNetwork(() async {
      final response = await _httpClient.get(_uri(path), headers: _headers);
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> postJson(
      String path, Map<String, dynamic> body) {
    return _guardNetwork(() async {
      final response = await _httpClient.post(
        _uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> patchJson(
      String path, Map<String, dynamic> body) {
    return _guardNetwork(() async {
      final response = await _httpClient.patch(
        _uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return _decode(response);
    });
  }

  Future<Map<String, dynamic>> deleteJson(String path) {
    return _guardNetwork(() async {
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
    return _guardNetwork(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers);
      request.fields.addAll(fields);
      request.files
          .add(await http.MultipartFile.fromPath(fileField, file.path));

      final streamed = await request.send();
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
    return _guardNetwork(() async {
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

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    });
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
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


