import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:korai_frontend/core/api/api_client.dart';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

final _expired = {
  'error': {'code': 'UNAUTHORIZED', 'message': 'Token invalide ou expire'},
};

void main() {
  test('renouvelle le jeton expiré puis rejoue la requête', () async {
    final client = ApiClient(
      httpClient: MockClient((req) async {
        final token = req.headers['authorization'];
        return token == 'Bearer neuf' ? _json(200, {'ok': true}) : _json(401, _expired);
      }),
    )..setAccessToken('ancien');
    var refreshes = 0;
    client.tokenRefresher = () async {
      refreshes++;
      client.setAccessToken('neuf');
      return true;
    };

    final result = await client.getJson('/cases');
    expect(result['ok'], isTrue);
    expect(refreshes, 1);
  });

  test('les requêtes parallèles partagent un seul renouvellement', () async {
    final client = ApiClient(
      httpClient: MockClient((req) async {
        return req.headers['authorization'] == 'Bearer neuf' ? _json(200, {'ok': true}) : _json(401, _expired);
      }),
    )..setAccessToken('ancien');
    var refreshes = 0;
    client.tokenRefresher = () async {
      refreshes++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      client.setAccessToken('neuf');
      return true;
    };

    await Future.wait([client.getJson('/a'), client.getJson('/b'), client.getJson('/c')]);
    expect(refreshes, 1);
  });

  test('session terminée : erreur claire et un seul signalement', () async {
    final client = ApiClient(httpClient: MockClient((_) async => _json(401, _expired)))..setAccessToken('ancien');
    var expired = 0;
    client.tokenRefresher = () async => false;
    client.onSessionExpired = () => expired++;

    final results = await Future.wait([
      client.getJson('/a').then<Object>((v) => v, onError: (Object e) => e),
      client.getJson('/b').then<Object>((v) => v, onError: (Object e) => e),
    ]);
    for (final r in results) {
      expect(r, isA<ApiException>().having((e) => e.code, 'code', 'SESSION_EXPIRED'));
    }
    expect(expired, 1);
  });

  test('pas de renouvellement sur la connexion (mauvais mot de passe)', () async {
    final client = ApiClient(
      httpClient: MockClient(
        (_) async => _json(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'Email ou mot de passe incorrect'},
        }),
      ),
    )..setAccessToken('ancien');
    var refreshes = 0;
    client.tokenRefresher = () async {
      refreshes++;
      return true;
    };

    await expectLater(
      client.postJson('/auth/login', {'email': 'a@b.sn', 'password': 'x'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'UNAUTHORIZED')),
    );
    expect(refreshes, 0);
  });
}
