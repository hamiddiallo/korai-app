import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/auth/session_controller.dart';
import 'package:korai_frontend/core/design/design.dart';
import 'package:korai_frontend/core/domain/korai_enums.dart';
import 'package:korai_frontend/core/widgets/consent_fields.dart';
import 'package:korai_frontend/features/admin/data/admin_repository.dart';
import 'package:korai_frontend/features/admin/domain/admin_models.dart';
import 'package:korai_frontend/features/admin/presentation/admin_audit_tab.dart';
import 'package:korai_frontend/features/auth/presentation/patient_register_page.dart';
import 'package:korai_frontend/features/nurse/data/nurse_repository.dart';
import 'package:korai_frontend/features/nurse/domain/ai_case.dart';
import 'package:korai_frontend/features/nurse/domain/patient.dart';
import 'package:korai_frontend/features/nurse/presentation/nurse_consultation_view_model.dart';
import 'package:korai_frontend/features/nurse/presentation/nurse_workspace.dart';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

AiCase _case(String id, {String status = 'AI_COMPLETED', LocalUpload upload = LocalUpload.none, String? patientId}) =>
    AiCase(
      id: id,
      status: status,
      summary: const AiSummary(confidenceLabel: AiConfidenceLabel.unknown, warnings: [], sources: []),
      createdAt: '2026-09-28T10:00:00Z',
      updatedAt: '2026-09-28T10:00:00Z',
      patientId: patientId ?? 'p-1',
      upload: upload,
    );

class _FakeNurseRepository extends NurseRepository {
  _FakeNurseRepository() : super(ApiClient());

  final consentUpdates = <Map<String, Object>>[];

  @override
  Future<List<Patient>> listPatients() async => const [Patient(id: 'p-1', firstName: 'Awa', lastName: 'Diop')];

  @override
  Future<List<AiCase>> listCases() async => [_case('case-1')];

  @override
  Future<List<AiCase>> listUnsentConsultations() async => [
        _case('local_1', status: 'PENDING_AI', upload: LocalUpload.pending),
        _case('local_2', status: 'PENDING_AI', upload: LocalUpload.failed),
      ];

  @override
  Future<Patient> updateConsents(String patientId,
      {required bool consentForAi, required bool consentForTeleExpertise}) async {
    consentUpdates.add({'id': patientId, 'ai': consentForAi, 'tele': consentForTeleExpertise});
    return Patient(
      id: patientId,
      firstName: 'Awa',
      lastName: 'Diop',
      consentForAi: consentForAi,
      consentForTeleExpertise: consentForTeleExpertise,
    );
  }
}

class _OfflineAfterFirstLoad extends _FakeNurseRepository {
  bool offline = false;

  @override
  Future<List<AiCase>> listCases() async {
    if (offline) throw ApiException('Pas de connexion', code: 'NETWORK');
    return [_case('case-1')];
  }

  @override
  Future<List<AiCase>> listUnsentConsultations() async =>
      offline ? [_case('local_new', status: 'PENDING_AI', upload: LocalUpload.pending)] : const [];
}

class _FakeAdminRepository extends AdminRepository {
  _FakeAdminRepository() : super(ApiClient());

  final requestedBefore = <String?>[];

  @override
  Future<AuditPage> listAudit({String? patientId, String? before}) async {
    requestedBefore.add(before);
    if (before == null) {
      return const AuditPage(
        entries: [
          AuditEntry(
            id: 'a-1',
            createdAt: '2026-09-28T10:00:00Z',
            action: 'ACCESS_DENIED',
            actorName: 'Kevin',
            actorRole: 'NURSE',
            details: {'method': 'GET', 'path': '/patients/p-1'},
          ),
          AuditEntry(
            id: 'a-2',
            createdAt: '2026-09-28T09:00:00Z',
            action: 'PATIENT_CONSENT_CHANGED',
            actorName: 'Hamid Diallo',
            actorRole: 'NURSE',
            patientName: 'Awa Diop',
            details: {'consentForAi': true, 'consentForTeleExpertise': false},
          ),
        ],
        nextBefore: '2026-09-28T09:00:00Z',
      );
    }
    return const AuditPage(
      entries: [AuditEntry(id: 'a-3', createdAt: '2026-09-27T09:00:00Z', action: 'AUTH_LOGIN_SUCCEEDED')],
    );
  }
}

Widget _app(Widget child) => MaterialApp(theme: KoraiTheme.light(), home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accords : décochés par défaut, chacun se coche séparément', (tester) async {
    var aiValue = false;
    var teleValue = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => ConsentFields(
            ai: aiValue,
            teleExpertise: teleValue,
            onChanged: ({required ai, required teleExpertise}) => setState(() {
              aiValue = ai;
              teleValue = teleExpertise;
            }),
          ),
        ),
      ),
    );
    expect(find.text('Accords du patient'), findsOneWidget);
    expect(tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).every((s) => !s.value), isTrue);
    await tester.tap(find.text('Avis d’un spécialiste'));
    await tester.pump();
    expect(teleValue, isTrue);
    expect(aiValue, isFalse, reason: 'l’accord pour l’IA reste à demander séparément');
    await tester.tap(find.text('Analyse par l’IA'));
    await tester.pump();
    expect(aiValue, isTrue);
    expect(teleValue, isTrue);
  });

  testWidgets('inscription patient : aucun accord envoyé par défaut, établissement au choix', (tester) async {
    Map<String, dynamic>? sent;
    final api = ApiClient(
      httpClient: MockClient((req) async {
        if (req.url.path == '/facilities') {
          return _json(200, {
            'facilities': [
              {'id': 'fac-fann', 'name': 'Fann'},
            ],
          });
        }
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(409, {
          'error': {'code': 'EMAIL_ALREADY_EXISTS', 'message': 'existe'},
        });
      }),
    );
    final session = AuthCubit(apiClient: api);
    await tester.pumpWidget(MaterialApp(theme: KoraiTheme.light(), home: PatientRegisterPage(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Où êtes-vous suivi ? (facultatif)'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'Awa');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Diop');
    await tester.enterText(find.widgetWithText(TextFormField, 'Adresse e-mail'), 'awa@korai.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'MotDePasse123');
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!['consentForAi'], isFalse);
    expect(sent!['consentForTeleExpertise'], isFalse);
    expect(sent!.containsKey('facilityId'), isFalse);
    await session.close();
  });

  test('les consultations pas encore envoyées apparaissent, bien classées', () async {
    final workspace = NurseWorkspace(_FakeNurseRepository());
    await workspace.refresh();
    expect(workspace.cases.map((c) => c.id), containsAll(['case-1', 'local_1', 'local_2']));
    expect(workspace.casesFor('p-1').length, 3, reason: 'visibles dans le dossier du patient');
    final pending = workspace.cases.firstWhere((c) => c.id == 'local_1');
    final refused = workspace.cases.firstWhere((c) => c.id == 'local_2');
    expect(NurseWorkspace.isWaiting(pending), isTrue);
    expect(NurseWorkspace.needsAction(refused), isTrue);
    expect(NurseWorkspace.isWaiting(refused), isFalse);
  });

  test('hors ligne : les consultations déjà chargées restent, celles à envoyer s’ajoutent', () async {
    final repo = _OfflineAfterFirstLoad();
    final workspace = NurseWorkspace(repo);
    await workspace.refresh();
    expect(workspace.cases.map((c) => c.id), ['case-1']);

    repo.offline = true;
    await workspace.refresh();
    expect(workspace.error, isA<ApiException>());
    expect(workspace.cases.map((c) => c.id).toSet(), {'case-1', 'local_new'});
  });

  test('accords d’un patient existant : envoyés seulement s’ils ont changé', () async {
    final repo = _FakeNurseRepository();
    final vm = NurseConsultationViewModel(repository: repo)
      ..patient = const Patient(id: 'p-1', firstName: 'Awa', lastName: 'Diop', consentForAi: true);
    vm
      ..consentForAi = true
      ..consentForTeleExpertise = false;
    await vm.saveConsentsIfChanged();
    expect(repo.consentUpdates, isEmpty);

    vm.setConsents(ai: true, teleExpertise: true);
    await vm.saveConsentsIfChanged();
    expect(repo.consentUpdates, [
      {'id': 'p-1', 'ai': true, 'tele': true},
    ]);
    expect(vm.patient!.consentForTeleExpertise, isTrue);
    await vm.close();
  });

  test('messages clairs pour les refus d’accès et d’accord', () {
    expect(
      friendlyError(ApiException('x', code: 'OUT_OF_SCOPE', statusCode: 403)),
      contains('pas rattaché à votre établissement'),
    );
    const consent = 'Le patient n’a pas donné son accord pour l’analyse par l’IA.';
    expect(friendlyError(ApiException(consent, code: 'CONSENT_AI_REQUIRED', statusCode: 403)), consent);
  });

  testWidgets('journal d’audit : actions lisibles et pages suivantes', (tester) async {
    final repo = _FakeAdminRepository();
    await tester.pumpWidget(_app(AuditLogView(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Accès refusé'), findsOneWidget);
    expect(find.text('Kevin (soignant)'), findsOneWidget);
    expect(find.text('GET /patients/p-1'), findsOneWidget);
    expect(find.text('Accords modifiés'), findsOneWidget);
    expect(find.text('IA : oui · télé-expertise : non'), findsOneWidget);
    expect(find.text('Dossier : Awa Diop'), findsOneWidget);

    await tester.ensureVisible(find.text('Afficher les actions plus anciennes'));
    await tester.tap(find.text('Afficher les actions plus anciennes'));
    await tester.pumpAndSettle();
    expect(repo.requestedBefore, [null, '2026-09-28T09:00:00Z']);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Afficher les actions plus anciennes'), findsNothing);
  });
}
