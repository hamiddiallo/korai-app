import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/notifications/notification_cubit.dart';
import 'package:korai_frontend/core/notifications/notification_models.dart';
import 'package:korai_frontend/core/notifications/notification_repository.dart';
import 'package:korai_frontend/core/refresh/live_refresh.dart';

/// Laisse s'écouler toutes les tâches en attente (microtâches comprises).
Future<void> settle() => Future<void>.delayed(Duration.zero);

AppNotification notification(String id, NotificationType type, {bool local = false}) => AppNotification(
      id: id,
      type: type,
      title: 'Titre',
      body: 'Texte',
      isRead: false,
      isLocal: local,
      createdAt: DateTime.utc(2026, 10, 9),
    );

/// Notifications du serveur, sans réseau ni base locale.
class _FakeNotifications extends NotificationRepository {
  _FakeNotifications() : super(ApiClient());

  List<AppNotification> server = [];

  @override
  Future<List<AppNotification>> refresh() async => [...server];

  @override
  Future<List<AppNotification>> cached() async => const [];

  @override
  Future<int> unreadCount() async => server.where((n) => !n.isRead).length;

  @override
  Future<void> clearLocal() async {}
}

void main() {
  group('une relecture à la fois', () {
    test('une demande pendant une relecture en relance une seule, juste après', () async {
      final runs = <Completer<void>>[];
      final refresh = SerialRefresh(() {
        final run = Completer<void>();
        runs.add(run);
        return run.future;
      });

      var done = false;
      unawaited(refresh().then((_) => done = true));
      refresh();
      refresh();
      await settle();
      expect(runs, hasLength(1), reason: 'jamais deux lectures en même temps');

      runs.first.complete();
      await settle();
      expect(runs, hasLength(2), reason: 'les demandes faites pendant la lecture n’en relancent qu’une');
      expect(done, isFalse, reason: 'l’appelant attend une lecture commencée après sa demande');

      runs.last.complete();
      await settle();
      expect(done, isTrue);
      expect(runs, hasLength(2));
    });
  });

  group('rafraîchissement automatique', () {
    late DateTime now;
    late LiveRefresh live;
    late List<String> reloads;

    LiveSubscription listen(String name, Set<LiveTopic> topics, {Duration? pollEvery}) => live.listen(
          topics: topics,
          pollEvery: pollEvery,
          reload: () async => reloads.add(name),
        );

    setUp(() {
      now = DateTime(2026, 10, 9, 9);
      live = LiveRefresh(clock: () => now)..start();
      reloads = [];
    });
    tearDown(() => live.dispose());

    test('un sujet modifié ne relit que les écrans qui l’affichent', () async {
      listen('file', {LiveTopic.expertise});
      listen('soignant', {LiveTopic.consultations, LiveTopic.patients});

      live.changed({LiveTopic.expertise});
      await settle();
      expect(reloads, ['file']);
    });

    test('retour au premier plan : tout est relu, mais rien hors session', () async {
      listen('file', {LiveTopic.expertise});
      listen('admin', const {});

      live
        ..paused()
        ..resumed();
      await settle();
      expect(reloads, unorderedEquals(['file', 'admin']));

      reloads.clear();
      live
        ..stop()
        ..paused()
        ..resumed();
      await settle();
      expect(reloads, isEmpty, reason: 'déconnecté : aucune requête');
    });

    test('relève périodique : seulement à échéance, au premier plan, et repoussée par une relecture', () async {
      listen('file', {LiveTopic.expertise}, pollEvery: const Duration(seconds: 30));
      listen('soignant', {LiveTopic.consultations}, pollEvery: const Duration(minutes: 2));

      now = now.add(const Duration(seconds: 31));
      live.poll();
      await settle();
      expect(reloads, ['file']);

      reloads.clear();
      now = now.add(const Duration(seconds: 20));
      live.changed({LiveTopic.expertise});
      now = now.add(const Duration(seconds: 15));
      live.poll();
      await settle();
      expect(reloads, ['file'], reason: 'relue il y a 15 s par la notification : pas encore à échéance');

      reloads.clear();
      live.paused();
      now = now.add(const Duration(minutes: 5));
      live.poll();
      await settle();
      expect(reloads, isEmpty, reason: 'en arrière-plan : pas de relève');
    });

    test('un écran fermé n’est plus relu', () async {
      final subscription = listen('file', {LiveTopic.expertise});
      subscription.cancel();
      live.changed({LiveTopic.expertise});
      await settle();
      expect(reloads, isEmpty);
    });

    test('chaque notification annonce les données qu’elle modifie', () {
      Set<LiveTopic> topics(NotificationType type) => LiveTopic.fromNotifications([notification('n', type)]);
      expect(topics(NotificationType.expertiseRequested), {LiveTopic.expertise});
      expect(topics(NotificationType.expertiseAssigned), {LiveTopic.consultations, LiveTopic.expertise});
      expect(topics(NotificationType.expertiseCompleted), {LiveTopic.consultations, LiveTopic.expertise});
      expect(topics(NotificationType.patientValidated), {LiveTopic.patients, LiveTopic.consultations});
      expect(topics(NotificationType.nurseRegistrationRequest), {LiveTopic.registrations});
      expect(topics(NotificationType.syncCompleted), isEmpty);
    });
  });

  group('notifications nouvelles', () {
    test('signalées une fois, sans compter celles présentes à la connexion ni les locales', () async {
      final repository = _FakeNotifications()..server = [notification('ancienne', NotificationType.expertiseRequested)];
      final announced = <List<String>>[];
      final cubit = NotificationCubit(
        repository: repository,
        onNewNotifications: (fresh) => announced.add([for (final n in fresh) n.id]),
      );

      await cubit.start();
      expect(announced, isEmpty, reason: 'déjà là à la connexion : les écrans viennent de se charger');

      repository.server = [
        notification('avis', NotificationType.expertiseCompleted),
        notification('sync', NotificationType.syncCompleted, local: true),
        ...repository.server,
      ];
      await cubit.refresh();
      await cubit.refresh();
      expect(announced, [
        ['avis']
      ]);

      await cubit.stop();
      await cubit.close();
    });
  });
}
