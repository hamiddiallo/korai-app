import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/auth/session_controller.dart';
import 'package:korai_frontend/core/design/design.dart';
import 'package:korai_frontend/core/domain/korai_enums.dart';
import 'package:korai_frontend/core/notifications/notification_cubit.dart';
import 'package:korai_frontend/core/notifications/notification_models.dart';
import 'package:korai_frontend/core/notifications/notification_repository.dart';
import 'package:korai_frontend/features/nurse/data/nurse_repository.dart';
import 'package:korai_frontend/features/nurse/domain/ai_case.dart';
import 'package:korai_frontend/features/nurse/domain/clinical_reference_item.dart';
import 'package:korai_frontend/features/nurse/domain/patient.dart';
import 'package:korai_frontend/features/nurse/presentation/nurse_workspace.dart';
import 'package:korai_frontend/features/nurse/presentation/screens/consultation_detail_page.dart';
import 'package:korai_frontend/features/patient/data/patient_repository.dart';
import 'package:korai_frontend/features/patient/presentation/patient_consultation_view_model.dart';
import 'package:korai_frontend/features/specialist/data/specialist_repository.dart';
import 'package:korai_frontend/features/specialist/presentation/screens/specialist_queue_tab.dart';
import 'package:korai_frontend/features/specialist/presentation/screens/specialist_review_page.dart';
import 'package:korai_frontend/features/specialist/presentation/specialist_inbox.dart';

const me = 'spec-moi';

/// Laisse s'écouler toutes les tâches en attente (microtâches comprises).
Future<void> settle() => Future<void>.delayed(Duration.zero);

ExpertiseInboxItem request(String id, {String? assignedTo, UrgencyLevel urgency = UrgencyLevel.medium}) =>
    ExpertiseInboxItem(
      expertiseId: 'exp-$id',
      consultationId: id,
      status: assignedTo == null ? ExpertiseStatus.pending : ExpertiseStatus.inReview,
      createdAt: '2026-10-09T08:00:00.000Z',
      assignedToUserId: assignedTo,
      patientFirstName: 'Awa',
      patientLastName: 'Diop',
      urgency: urgency,
    );

/// File du serveur ; chaque lecture attend qu'on lui réponde ([answer]).
class _InboxServer extends SpecialistRepository {
  _InboxServer() : super(ApiClient());

  final reads = <Completer<List<ExpertiseInboxItem>>>[];
  final assigned = <String>[];

  @override
  Future<List<ExpertiseInboxItem>> listInbox() {
    final read = Completer<List<ExpertiseInboxItem>>();
    reads.add(read);
    return read.future;
  }

  /// Répond à la plus ancienne lecture en attente.
  Future<void> answer(List<ExpertiseInboxItem> items) async {
    reads.firstWhere((r) => !r.isCompleted).complete(items);
    await settle();
  }

  @override
  Future<AiCase?> findCase(String consultationId) async =>
      AiCase.fromJson({'id': consultationId, 'status': 'PENDING_SPECIALIST_REVIEW', 'patientId': 'p-1'});

  @override
  Future<void> assign(String consultationId) async => assigned.add(consultationId);
}

class _NoNotifications extends NotificationRepository {
  _NoNotifications() : super(ApiClient());

  @override
  Future<List<AppNotification>> refresh() async => const [];

  @override
  Future<List<AppNotification>> cached() async => const [];

  @override
  Future<int> unreadCount() async => 0;
}

Widget app(Widget child) => BlocProvider(
      create: (_) => NotificationCubit(repository: _NoNotifications()),
      child: MaterialApp(theme: KoraiTheme.light(), home: child),
    );

void main() {
  group('file d’expertise', () {
    late _InboxServer server;
    late SpecialistInbox inbox;

    Future<void> load(List<ExpertiseInboxItem> items) async {
      final done = inbox.refresh();
      await settle();
      await server.answer(items);
      await done;
    }

    setUp(() {
      server = _InboxServer();
      inbox = SpecialistInbox(server, currentUserId: me);
    });

    test('un dossier pris en charge quitte la file et passe dans « Mes dossiers »', () async {
      await load([request('a'), request('b', assignedTo: me)]);
      expect(inbox.queue.map((i) => i.consultationId), ['a']);
      expect(inbox.mine.map((i) => i.consultationId), ['b']);
      expect(inbox.toTakeCount, 1);
    });

    test('prise en charge : la file change tout de suite, et une lecture plus ancienne ne la fait pas revenir',
        () async {
      await load([request('a')]);

      // Relève périodique partie avant la prise en charge…
      unawaited(inbox.refresh());
      await settle();
      inbox.markTakenByMe('a');
      expect(inbox.queue, isEmpty);
      expect(inbox.mine.single.consultationId, 'a');
      final queues = <List<String>>[];
      inbox.addListener(() => queues.add([for (final i in inbox.queue) i.consultationId]));

      // … elle répond avec l'ancien état : écarté, relu.
      await server.answer([request('a')]);
      await server.answer([request('a', assignedTo: me)]);
      await server.answer([request('a', assignedTo: me)]);

      expect(queues.where((q) => q.contains('a')), isEmpty, reason: 'jamais réapparu dans la file');
      expect(inbox.mine.single.consultationId, 'a');
      expect(server.reads.every((r) => r.isCompleted), isTrue);
    });

    test('avis envoyé : le dossier quitte « Mes dossiers » aussitôt', () async {
      await load([request('a', assignedTo: me)]);
      inbox.remove('a');
      expect(inbox.mine, isEmpty);
      await server.answer(const []);
    });

    testWidgets('écran de la file : seul ce qui reste à prendre, avec un lien vers « Mes dossiers »', (tester) async {
      tester.view.physicalSize = const Size(1179, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => load([request('a'), request('b', assignedTo: me)]));
      var wentToMine = false;
      final opened = <String>[];
      await tester.pumpWidget(app(Scaffold(
        body: SpecialistQueueTab(
          inbox: inbox,
          userName: 'Fatou Sow',
          onOpen: (item) => opened.add(item.consultationId),
          onNotificationTap: (_) {},
          onGoToMine: () => wentToMine = true,
        ),
      )));

      expect(find.text('Vous avez 1 dossier pris en charge, avis à rendre.'), findsOneWidget);
      expect(find.text('Pris en charge par vous'), findsNothing, reason: 'les dossiers pris ne sont plus dans la file');
      await tester.tap(find.text('Mes dossiers'));
      expect(wentToMine, isTrue);
    });
  });

  group('dossier ouvert par le spécialiste', () {
    late _InboxServer server;
    late SpecialistInbox inbox;

    Future<void> openReview(WidgetTester tester, ExpertiseInboxItem item) async {
      tester.view.physicalSize = const Size(1179, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(SpecialistReviewPage(
        repository: server,
        inbox: inbox,
        item: item,
        currentUserId: me,
      )));
      await tester.pumpAndSettle();
    }

    setUp(() {
      server = _InboxServer();
      inbox = SpecialistInbox(server, currentUserId: me);
    });

    testWidgets('pris par un confrère pendant la lecture : plus de prise en charge possible', (tester) async {
      await tester.runAsync(() async {
        final done = inbox.refresh();
        await settle();
        await server.answer([request('a')]);
        await done;
      });
      await openReview(tester, inbox.find('a')!);
      expect(find.text('Prendre en charge'), findsOneWidget);

      // Relève suivante : un confrère a pris le dossier, il n'est plus dans ma file.
      await tester.runAsync(() async {
        final done = inbox.refresh();
        await settle();
        await server.answer(const []);
        await done;
      });
      await tester.pump();

      expect(find.text('Dossier retiré de votre file'), findsOneWidget);
      expect(find.text('Prendre en charge'), findsNothing);
    });

    testWidgets('prise en charge : le dossier passe dans « Mes dossiers » sans attendre', (tester) async {
      await tester.runAsync(() async {
        final done = inbox.refresh();
        await settle();
        await server.answer([request('a')]);
        await done;
      });
      await openReview(tester, inbox.find('a')!);

      await tester.tap(find.text('Prendre en charge'));
      await tester.pump();
      await tester.pump();

      expect(server.assigned, ['a']);
      expect(inbox.queue, isEmpty);
      expect(inbox.mine.single.consultationId, 'a');
      expect(find.text('Envoyer l’avis'), findsOneWidget);
      await tester.runAsync(() => server.answer([request('a', assignedTo: me)]));
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('détail d’une consultation ouvert : l’avis reçu apparaît sans le rouvrir', (tester) async {
    final waiting = AiCase.fromJson({'id': 'c-1', 'status': 'PENDING_SPECIALIST_REVIEW', 'patientId': 'p-1'});
    final answered = AiCase.fromJson({'id': 'c-1', 'status': 'SPECIALIST_COMPLETED', 'patientId': 'p-1'});
    var current = waiting;
    final updates = ValueNotifier(0);
    addTearDown(updates.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: KoraiTheme.light(),
      home: ConsultationDetailPage(
        consultation: waiting,
        patientName: 'Awa Diop',
        updates: updates,
        latest: (id) => id == current.id ? current : null,
      ),
    ));
    expect(find.text('En attente d’avis'), findsWidgets);

    current = answered;
    updates.value++;
    await tester.pump();
    expect(find.text('Avis reçu'), findsWidgets);
    expect(find.text('En attente d’avis'), findsNothing);
  });

  group('espace du soignant', () {
    test('une demande d’avis faite pendant une relecture n’est pas écrasée par l’ancien état', () async {
      final repository = _NurseServer();
      final workspace = NurseWorkspace(repository);
      repository.cases = [
        AiCase.fromJson({'id': 'c-1', 'status': 'AI_COMPLETED', 'patientId': 'p-1'})
      ];
      await workspace.refresh();

      repository.hold = Completer<void>();
      final reading = workspace.refresh();
      await settle();
      workspace.upsertCase(AiCase.fromJson({'id': 'c-1', 'status': 'PENDING_SPECIALIST_REVIEW', 'patientId': 'p-1'}));
      repository.cases = [
        AiCase.fromJson({'id': 'c-1', 'status': 'PENDING_SPECIALIST_REVIEW', 'patientId': 'p-1'})
      ];
      repository.hold!.complete();
      repository.hold = null;
      await reading;

      expect(workspace.caseById('c-1')!.status, 'PENDING_SPECIALIST_REVIEW');
    });

    test('hors ligne : l’erreur reste affichée pendant les relectures (pas de clignotement)', () async {
      final repository = _NurseServer()..offline = true;
      final workspace = NurseWorkspace(repository);
      await workspace.refresh();
      expect(workspace.error, isNotNull);

      final errors = <Object?>[];
      workspace.addListener(() => errors.add(workspace.error));
      await workspace.refresh();
      expect(errors, everyElement(isNotNull));
    });
  });

  group('espace du patient', () {
    test('dossier validé par le soignant : visible à la relecture, saisie en cours conservée', () async {
      final repository = _PatientServer();
      final vm = PatientConsultationViewModel(repository: repository, session: _PatientSession());
      await vm.initialize();
      expect(vm.isReadOnly, isFalse);

      vm.toggleSelection('SYMPTOM', 'sym-otalgie', true);
      repository.patient = repository.patient.validated();
      repository.cases = [
        AiCase.fromJson({'id': 'c-1', 'status': 'SPECIALIST_COMPLETED', 'patientId': 'pat-1', 'symptoms': 'Fièvre'}),
      ];
      await vm.refresh();

      expect(vm.isReadOnly, isTrue);
      expect(vm.consultations.single.id, 'c-1');
      expect(vm.selectedSymptomIds, {'sym-otalgie'}, reason: 'la relecture ne réapplique pas le pré-remplissage');
      await vm.close();
    });
  });
}

class _NurseServer extends NurseRepository {
  _NurseServer() : super(ApiClient());

  List<AiCase> cases = const [];
  bool offline = false;
  Completer<void>? hold;

  @override
  Future<List<Patient>> listPatients() async => const [];

  @override
  Future<List<AiCase>> listCases() async {
    final snapshot = [...cases];
    await hold?.future;
    if (offline) throw ApiException('Pas de réseau', code: 'NETWORK_ERROR');
    return snapshot;
  }

  @override
  Future<List<AiCase>> listUnsentConsultations() async => const [];
}

extension on Patient {
  Patient validated() => Patient(
        id: id,
        firstName: firstName,
        lastName: lastName,
        isValidated: true,
        consentForAi: consentForAi,
        consentForTeleExpertise: consentForTeleExpertise,
      );
}

class _PatientServer extends PatientRepository {
  _PatientServer() : super(ApiClient());

  Patient patient = const Patient(
    id: 'pat-1',
    firstName: 'Awa',
    lastName: 'Diop',
    isValidated: false,
    consentForAi: true,
  );
  List<AiCase> cases = [
    AiCase.fromJson({'id': 'pre-1', 'status': 'AI_COMPLETED', 'patientId': 'pat-1', 'symptoms': 'Fièvre'}),
  ];

  @override
  Future<List<ClinicalReferenceItem>> listClinicalItems(String type) async => const [];

  @override
  Future<Patient> getPatient(String id) async => patient;

  @override
  Future<List<AiCase>> listCases() async => [...cases];
}

class _PatientSession extends AuthCubit {
  _PatientSession() : super(apiClient: ApiClient()) {
    emit(const AuthState(
      user: SessionUser(
          id: 'u-1', fullName: 'Awa Diop', email: 'awa@korai.local', role: 'PATIENT', linkedPatientId: 'pat-1'),
    ));
  }
}
