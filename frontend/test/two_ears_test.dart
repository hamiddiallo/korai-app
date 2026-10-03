import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/design/design.dart';
import 'package:korai_frontend/core/domain/consultation_create_payload.dart';
import 'package:korai_frontend/core/domain/korai_enums.dart';
import 'package:korai_frontend/core/widgets/orl_image_capture_step.dart';
import 'package:korai_frontend/features/nurse/data/local/nurse_local_dao.dart';
import 'package:korai_frontend/features/nurse/data/nurse_repository.dart';
import 'package:korai_frontend/features/nurse/domain/ai_case.dart';
import 'package:korai_frontend/features/nurse/domain/patient.dart';
import 'package:korai_frontend/features/nurse/presentation/nurse_consultation_view_model.dart';

/// Photo PNG de 1 × 1 pixel.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

File _photo(String name) => File('${Directory.systemTemp.path}/korai-$name.png')..writeAsBytesSync(_png);

/// Enregistre ce que l'écran envoie, sans base locale ni réseau.
class _CapturingRepository extends NurseRepository {
  _CapturingRepository() : super(ApiClient());

  Map<EarSide, File>? savedPhotos;
  Map<EarSide, File>? sentPhotos;
  ConsultationCreatePayload? sentPayload;

  @override
  Future<LocalConsultationDraft> savePendingDiagnosisDraft({
    required Patient patient,
    required ConsultationCreatePayload payload,
    Map<EarSide, File> photos = const {},
  }) async {
    savedPhotos = photos;
    return const LocalConsultationDraft(localId: 'local_1');
  }

  @override
  Future<AiCase> diagnose({
    required ConsultationCreatePayload payload,
    Map<EarSide, File> photos = const {},
    String? localConsultationId,
  }) async {
    sentPhotos = photos;
    sentPayload = payload;
    return AiCase.fromJson({'id': 'case-1', 'status': 'AI_COMPLETED'});
  }
}

void main() {
  group('photos des deux tympans dans le formulaire', () {
    test('seules les photos des oreilles choisies partent, droite puis gauche ; rien n’est perdu', () {
      final vm = NurseConsultationViewModel(repository: _CapturingRepository());
      final left = _photo('gauche');
      final right = _photo('droite');
      vm.photos
        ..[EarSide.left] = left
        ..[EarSide.right] = right;

      vm.setEarSide(EarSide.right);
      expect(vm.photosToSend, {EarSide.right: right});
      vm.setEarSide(EarSide.both);
      expect(vm.photosToSend.keys, [EarSide.right, EarSide.left]);
      expect(vm.photosToSend[EarSide.left], left, reason: 'la photo gauche est revenue avec « les deux »');
    });

    test('la description disparaît avec la dernière photo seulement', () {
      final vm = NurseConsultationViewModel(repository: _CapturingRepository())..earSide = EarSide.both;
      vm.photos
        ..[EarSide.left] = _photo('g2')
        ..[EarSide.right] = _photo('d2');
      vm.setImageDescription('Tympan droit rouge');

      vm.removePhoto(EarSide.right);
      expect(vm.imageDescription, 'Tympan droit rouge');
      vm.removePhoto(EarSide.left);
      expect(vm.imageDescription, isEmpty);
      expect(vm.hasPhotos, isFalse);
    });

    test('l’envoi transmet les deux photos et la consultation « les deux oreilles »', () async {
      final repo = _CapturingRepository();
      final left = _photo('g3');
      final right = _photo('d3');
      final vm = NurseConsultationViewModel(repository: repo)
        ..patient = const Patient(id: 'p-1', firstName: 'Awa', lastName: 'Diop', consentForAi: true)
        ..consentForAi = true
        ..earSide = EarSide.both;
      vm.photos
        ..[EarSide.left] = left
        ..[EarSide.right] = right;

      await vm.diagnose(
        patientId: 'p-1',
        firstName: 'Awa',
        lastName: 'Diop',
        phone: '',
        address: '',
        age: '34',
        sex: 'F',
        notes: '',
      );

      expect(repo.savedPhotos, {EarSide.right: right, EarSide.left: left});
      expect(repo.sentPhotos?.keys, [EarSide.right, EarSide.left]);
      expect(repo.sentPayload?.earSide, EarSide.both);
    });
  });

  group('écran de prise des photos', () {
    Widget screen({
      required EarSide earSide,
      Map<EarSide, File> photos = const {},
      List<String>? calls,
    }) =>
        MaterialApp(
          theme: KoraiTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrlImageCaptureStep(
                photos: photos,
                earSide: earSide,
                onEarSideChanged: (side) => calls?.add('oreille ${side.value}'),
                editingSide: null,
                description: '',
                onDescriptionChanged: (_) {},
                onCamera: (side) => calls?.add('photo ${side.value}'),
                onGallery: (side) => calls?.add('galerie ${side.value}'),
                onRotateLeft: (_) {},
                onRotateRight: (_) {},
                onFlipHorizontal: (_) {},
                onBrighten: (_) {},
                onDarken: (_) {},
                onRemove: (side) => calls?.add('retirer ${side.value}'),
              ),
            ),
          ),
        );

    testWidgets('« Les deux » est proposé ; une oreille : un seul emplacement photo', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(screen(earSide: EarSide.right, calls: calls));

      expect(find.text('Les deux'), findsOneWidget);
      expect(find.text('Oreille droite'), findsNothing, reason: 'pas de titre par oreille pour une seule photo');
      await tester.tap(find.text('Prendre la photo'));
      await tester.tap(find.text('Les deux'));
      expect(calls, ['photo RIGHT', 'oreille BOTH']);
    });

    testWidgets('les deux oreilles : un emplacement par tympan, chacun agit sur son oreille', (tester) async {
      tester.view.physicalSize = const Size(1179, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await tester.pumpWidget(screen(earSide: EarSide.both, photos: {EarSide.left: _photo('g4')}, calls: calls));

      final right = find.byKey(const ValueKey('photo-RIGHT'));
      final left = find.byKey(const ValueKey('photo-LEFT'));
      expect(find.descendant(of: right, matching: find.text('Oreille droite')), findsOneWidget);
      expect(find.descendant(of: left, matching: find.text('Oreille gauche')), findsOneWidget);
      expect(find.descendant(of: left, matching: find.byType(Image)), findsOneWidget);
      expect(find.text('Ce que vous voyez (facultatif)'), findsOneWidget);

      await tester.tap(find.descendant(of: right, matching: find.text('Prendre la photo')));
      await tester.tap(find.descendant(of: right, matching: find.text('Galerie')));
      await tester.tap(find.descendant(of: left, matching: find.text('Retirer')));
      expect(calls, ['photo RIGHT', 'galerie RIGHT', 'retirer LEFT']);
    });
  });

  group('envoi au serveur', () {
    test('une photo par oreille : champs fileRight et fileLeft, type lu dans l’image', () async {
      var body = '';
      var contentType = '';
      final client = ApiClient(
        httpClient: MockClient((request) async {
          body = latin1.decode(request.bodyBytes);
          contentType = request.headers['content-type'] ?? '';
          return http.Response(jsonEncode({'case': {}}), 201, headers: {'content-type': 'application/json'});
        }),
      );
      await client.postMultipartUploads(
        path: '/cases/diagnose',
        fields: {'earSide': 'BOTH'},
        uploads: [
          MultipartUpload(
              field: 'fileRight', bytes: Uint8List.fromList(_png), fileName: 'droite.png', mimeType: 'image/png'),
          MultipartUpload(
              field: 'fileLeft', bytes: Uint8List.fromList(_png), fileName: 'gauche.png', mimeType: 'image/png'),
        ],
      );
      expect(contentType, startsWith('multipart/form-data'));
      expect(body, contains('name="fileRight"; filename="droite.png"'));
      expect(body, contains('name="fileLeft"; filename="gauche.png"'));
      expect('content-type: image/png'.allMatches(body.toLowerCase()).length, 2);
    });

    test('photos en attente : chacune part dans le champ de son oreille', () {
      LocalOtoscopicImageSyncRecord record(EarSide side) => LocalOtoscopicImageSyncRecord(
            localId: 'img',
            bytes: Uint8List.fromList(_png),
            mimeType: 'image/png',
            fileName: 'x.png',
            earSide: side,
          );
      expect(record(EarSide.right).toUpload().field, 'fileRight');
      expect(record(EarSide.left).toUpload().field, 'fileLeft');
      expect(record(EarSide.both).toUpload().field, 'file', reason: 'photo unique d’une version précédente');
    });
  });
}
