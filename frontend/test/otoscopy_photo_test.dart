import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/design/design.dart';
import 'package:korai_frontend/core/domain/korai_enums.dart';
import 'package:korai_frontend/core/widgets/otoscopy_photo.dart';
import 'package:korai_frontend/features/nurse/domain/ai_case.dart';

/// Photo PNG de 1 × 1 pixel.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _image = CaseImage(id: 'img-1', url: '/cases/case-1/images/img-1', earSide: EarSide.left);

Widget _app(ProtectedImageLoader loader) => RepositoryProvider<ProtectedImageLoader>.value(
      value: loader,
      child: MaterialApp(
        theme: KoraiTheme.light(),
        home: const Scaffold(body: SingleChildScrollView(child: OtoscopyPhotos(images: [_image]))),
      ),
    );

void main() {
  test('la consultation reçoit ses photos du serveur', () {
    final c = AiCase.fromJson({
      'id': 'case-1',
      'status': 'AI_COMPLETED',
      'images': [
        {'id': 'img-1', 'url': '/cases/case-1/images/img-1', 'earSide': 'RIGHT'},
      ],
    });
    expect(c.images.single.url, '/cases/case-1/images/img-1');
    expect(c.images.single.earSide, EarSide.right);
    expect(AiCase.fromJson({'id': 'x', 'status': 'DRAFT'}).images, isEmpty);
  });

  test('chargeur : une seule requête par photo, mémoire bornée, oubli à la déconnexion', () async {
    final calls = <String>[];
    final loader = ProtectedImageLoader((url) async {
      calls.add(url);
      return Uint8List.fromList([calls.length]);
    }, capacity: 2);

    await Future.wait([loader.load('/a'), loader.load('/a')]);
    await loader.load('/a');
    expect(calls, ['/a'], reason: 'requêtes simultanées partagées, puis cache');

    await loader.load('/b');
    await loader.load('/c'); // dépasse la capacité : /a, le plus ancien, est oublié
    await loader.load('/a');
    expect(calls, ['/a', '/b', '/c', '/a']);

    loader.clear();
    await loader.load('/b');
    expect(calls.last, '/b', reason: 'plus rien en mémoire après la déconnexion');
  });

  test('lecture protégée : jeton envoyé, refus traduit en erreur claire', () async {
    final client = ApiClient(
      httpClient: MockClient((request) async {
        if (request.headers['authorization'] != 'Bearer jeton') return http.Response('', 401);
        if (request.url.path.endsWith('/interdite')) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'OUT_OF_SCOPE', 'message': 'Cette consultation n’est pas accessible.'},
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(_png, 200, headers: {'content-type': 'image/png'});
      }),
    )..setAccessToken('jeton');

    expect(await client.getBytes('/cases/c/images/i'), _png);
    expect(
      () => client.getBytes('/cases/c/images/interdite'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'OUT_OF_SCOPE')),
    );
  });

  testWidgets('la photo s’affiche et s’agrandit au toucher', (tester) async {
    await tester.pumpWidget(_app(ProtectedImageLoader((_) async => _png)));
    await tester.pumpAndSettle();

    expect(find.text('Photo du tympan · Oreille gauche'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.text('Tympan · Oreille gauche'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('photo indisponible : message clair et « Réessayer »', (tester) async {
    var attempts = 0;
    final loader = ProtectedImageLoader((_) async {
      attempts++;
      if (attempts == 1) throw ApiException('Serveur injoignable.', code: 'NETWORK');
      return _png;
    });
    await tester.pumpWidget(_app(loader));
    await tester.pumpAndSettle();

    expect(find.text('Serveur injoignable.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(attempts, 2);
  });
}
