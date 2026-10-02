import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/design/design.dart';
import 'package:korai_frontend/core/domain/clinical_urgency.dart';
import 'package:korai_frontend/core/domain/korai_enums.dart';
import 'package:korai_frontend/features/admin/data/admin_repository.dart';
import 'package:korai_frontend/features/admin/domain/admin_models.dart' as admin;
import 'package:korai_frontend/features/admin/presentation/admin_clinical_items_tab.dart';
import 'package:korai_frontend/features/nurse/data/nurse_repository.dart';
import 'package:korai_frontend/features/nurse/domain/clinical_reference_item.dart';
import 'package:korai_frontend/features/nurse/presentation/nurse_consultation_view_model.dart';

/// Cas de référence partagés avec le serveur : l'aperçu de l'app doit donner
/// exactement le niveau que le backend enregistrera.
const _fixturePath = '../backend/test/fixtures/urgency-cases.json';

UrgencyLevel _level(String value) => switch (value) {
      'LOW' => UrgencyLevel.low,
      'MEDIUM' => UrgencyLevel.medium,
      'HIGH' => UrgencyLevel.high,
      _ => throw ArgumentError(value),
    };

ClinicalReferenceItem _item(String id, String type, int score) =>
    ClinicalReferenceItem(id: id, type: type, label: id, isActive: true, sortOrder: 0, dangerScore: score);

class _FakeAdminRepository extends AdminRepository {
  _FakeAdminRepository() : super(ApiClient());

  final created = <Map<String, dynamic>>[];

  @override
  Future<List<admin.ClinicalReferenceItem>> listClinicalItems(String type) async => const [
        admin.ClinicalReferenceItem(
          id: 't1',
          type: 'TOUCH_CHECK',
          label: 'Sensibilité mastoïdienne',
          isActive: true,
          sortOrder: 30,
          dangerScore: 3,
        ),
      ];

  @override
  Future<admin.ClinicalReferenceItem> createClinicalItem(Map<String, dynamic> input) async {
    created.add(input);
    return admin.ClinicalReferenceItem.fromJson({...input, 'id': 'nouveau', 'sortOrder': 0});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixtureFile = File(_fixturePath);
  final fixture = fixtureFile.existsSync()
      ? jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>
      : throw StateError('Cas partagés introuvables : $_fixturePath (lancer depuis frontend/).');

  group('formule identique au serveur', () {
    for (final c in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final level = ClinicalUrgency.compute(
          signScores: (c['signs'] as List).cast<int>(),
          historyScores: (c['histories'] as List).cast<int>(),
        );
        expect(level, _level(c['expected'] as String));
      });
    }

    test('résultats des vérifications au toucher', () {
      for (final t in (fixture['touchObservations'] as List).cast<Map<String, dynamic>>()) {
        expect(ClinicalUrgency.isAbnormalTouchFinding(t['observation'] as String?), t['abnormal'],
            reason: '${t['observation']}');
      }
    });
  });

  group('aperçu pendant la consultation', () {
    late NurseConsultationViewModel vm;

    setUp(() {
      vm = NurseConsultationViewModel(repository: NurseRepository(ApiClient()));
      vm.symptoms = [_item('otalgie', 'SYMPTOM', 1)];
      vm.medicalHistories = [_item('cholesteatome', 'MEDICAL_HISTORY', 3)];
      vm.touchChecks = [_item('mastoide', 'TOUCH_CHECK', 3)];
    });
    tearDown(() => vm.close());

    test('une palpation anormale compte, un résultat normal non', () {
      expect(vm.hasUrgencyInput, isFalse);
      vm.toggleTouchCheck('mastoide', true); // « Normal (négatif) » par défaut
      expect(vm.hasUrgencyInput, isTrue);
      expect(vm.computedUrgency(), UrgencyLevel.low);

      vm.setTouchCheckObservation('mastoide', 'Anormal — léger');
      expect(vm.computedUrgency(), UrgencyLevel.high);
    });

    test('un antécédent grave avec un symptôme léger reste à « moyen »', () {
      vm.selectedSymptomIds.add('otalgie');
      vm.selectedMedicalHistoryIds.add('cholesteatome');
      expect(vm.computedUrgency(), UrgencyLevel.medium);
    });
  });

  test('le cache hors ligne garde le score de danger', () {
    final item = _item('mastoide', 'TOUCH_CHECK', 3);
    final restored = ClinicalReferenceItem.fromJson(jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>);
    expect(restored.dangerScore, 3);
    expect(restored.type, 'TOUCH_CHECK');
  });

  testWidgets('console admin : score de danger réglable pour l’examen au toucher', (tester) async {
    final repo = _FakeAdminRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: KoraiTheme.light(),
        home: Scaffold(body: ClinicalItemsTab(repository: repo, kind: ClinicalKind.touch)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Score de danger : 3 sur 3'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Compte dans l’urgence seulement si le résultat est anormal.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Libellé'), 'Otoscopie pneumatique');
    await tester.tap(find.text('0 — Bénin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 — Préoccupant').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(repo.created.single, containsPair('type', 'TOUCH_CHECK'));
    expect(repo.created.single, containsPair('dangerScore', 2));
  });
}
