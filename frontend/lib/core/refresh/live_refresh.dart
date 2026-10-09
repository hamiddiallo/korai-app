import 'dart:async';

import 'package:flutter/widgets.dart';

import '../notifications/notification_models.dart';

/// Données affichées par plusieurs écrans et modifiées par d'autres personnes.
enum LiveTopic {
  /// Consultations : analyse, demande d'avis, avis du spécialiste.
  consultations,

  /// File de télé-expertise partagée entre spécialistes.
  expertise,

  /// Dossiers patients : validation, accords.
  patients,

  /// Inscriptions de soignants à valider.
  registrations;

  /// Ce que des notifications reçues du serveur annoncent comme modifié.
  static Set<LiveTopic> fromNotifications(Iterable<AppNotification> notifications) =>
      {for (final n in notifications) ..._announcedBy(n.type)};

  static List<LiveTopic> _announcedBy(NotificationType type) => switch (type) {
        NotificationType.expertiseRequested => const [LiveTopic.expertise],
        NotificationType.expertiseAssigned || NotificationType.expertiseCompleted => const [
            LiveTopic.consultations,
            LiveTopic.expertise
          ],
        NotificationType.patientValidated => const [LiveTopic.patients, LiveTopic.consultations],
        NotificationType.nurseRegistrationRequest => const [LiveTopic.registrations],
        _ => const [],
      };
}

/// Une relecture à la fois. Une demande faite pendant une relecture en
/// programme une seule autre juste après : l'écran affiche toujours une lecture
/// commencée après la dernière demande, sans requêtes qui se croisent.
class SerialRefresh {
  SerialRefresh(this._run);

  final Future<void> Function() _run;
  Future<void>? _running;
  bool _again = false;

  Future<void> call() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final done = Completer<void>();
    _running = done.future;
    _loop(done);
    return done.future;
  }

  Future<void> _loop(Completer<void> done) async {
    try {
      do {
        _again = false;
        await _run();
      } while (_again);
      done.complete();
    } catch (error, stack) {
      done.completeError(error, stack);
    } finally {
      _running = null;
    }
  }
}

/// Rafraîchissement automatique des écrans.
///
/// Un écran s'abonne ([listen]) aux sujets qu'il affiche ; ses données sont
/// relues sans geste de l'utilisateur :
/// - au retour de l'application au premier plan (tout est relu) ;
/// - quand un sujet change ([changed]) : notification reçue, action faite ailleurs ;
/// - à intervalle régulier ([LiveSubscription.pollEvery]) pour ce que d'autres
///   modifient sans notification (dossier pris par un confrère).
///
/// Rien n'est relu hors session ni quand l'application est en arrière-plan.
class LiveRefresh {
  LiveRefresh({DateTime Function()? clock, this.tick = const Duration(seconds: 15)}) : _clock = clock ?? DateTime.now;

  /// Fréquence à laquelle les relèves périodiques arrivées à échéance partent.
  final Duration tick;
  final DateTime Function() _clock;
  final _subscriptions = <LiveSubscription>[];
  Timer? _timer;
  bool _active = false;
  bool _foreground = true;

  /// Session ouverte et données locales accessibles.
  bool get isActive => _active;

  /// `reload` relit les données de l'écran ; il est appelé sans chevauchement.
  LiveSubscription listen({
    Set<LiveTopic> topics = const {},
    required Future<void> Function() reload,
    Duration? pollEvery,
  }) {
    final subscription = LiveSubscription._(this, topics, pollEvery, reload);
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Ces sujets ont changé : les écrans qui les affichent les relisent.
  void changed(Set<LiveTopic> topics) {
    if (topics.isEmpty) return;
    for (final subscription in [..._subscriptions]) {
      if (subscription.topics.any(topics.contains)) subscription._reload();
    }
  }

  /// Session ouverte : relèves périodiques actives.
  void start() {
    _active = true;
    _schedule();
  }

  /// Déconnexion : plus aucune relecture.
  void stop() {
    _active = false;
    _schedule();
  }

  /// Application en arrière-plan : pas de requêtes pour un écran invisible.
  void paused() {
    _foreground = false;
    _schedule();
  }

  /// Retour au premier plan : tout ce qui est affiché a pu changer entre-temps.
  void resumed() {
    final wasAway = !_foreground;
    _foreground = true;
    _schedule();
    if (wasAway && _active) {
      for (final subscription in [..._subscriptions]) {
        subscription._reload();
      }
    }
  }

  /// Lance les relèves périodiques arrivées à échéance (appelé par la minuterie).
  @visibleForTesting
  void poll() {
    if (!_active || !_foreground) return;
    final now = _clock();
    for (final subscription in [..._subscriptions]) {
      if (subscription._isDue(now)) subscription._reload();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = _active && _foreground ? Timer.periodic(tick, (_) => poll()) : null;
  }

  void dispose() {
    stop();
    _subscriptions.clear();
  }
}

class LiveSubscription {
  LiveSubscription._(this._live, this.topics, this.pollEvery, Future<void> Function() reload)
      : _refresh = SerialRefresh(reload),
        _lastReload = _live._clock();

  final LiveRefresh _live;
  final Set<LiveTopic> topics;

  /// Relève périodique : relu au plus tard après ce délai sans relecture.
  final Duration? pollEvery;
  final SerialRefresh _refresh;
  DateTime _lastReload;

  bool _isDue(DateTime now) => pollEvery != null && now.difference(_lastReload) >= pollEvery!;

  void _reload() {
    _lastReload = _live._clock();
    // Les écrans affichent eux-mêmes leurs erreurs de chargement.
    unawaited(_refresh().catchError((Object _) {}));
  }

  void cancel() => _live._subscriptions.remove(this);
}

/// Donne aux écrans l'accès au [LiveRefresh] de l'application.
class LiveRefreshScope extends InheritedWidget {
  const LiveRefreshScope({super.key, required this.live, required super.child});

  final LiveRefresh live;

  /// `null` hors de l'application (écran testé seul) : pas de relecture automatique.
  static LiveRefresh? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<LiveRefreshScope>()?.live;

  @override
  bool updateShouldNotify(LiveRefreshScope oldWidget) => !identical(live, oldWidget.live);
}

/// Écran qui charge ses données : elles sont relues automatiquement (retour au
/// premier plan, sujet modifié, relève périodique si [livePollEvery]).
mixin LiveReloadState<T extends StatefulWidget> on State<T> {
  /// Sujets affichés par l'écran ; vide : relu seulement au retour au premier plan.
  Set<LiveTopic> get liveTopics => const {};

  Duration? get livePollEvery => null;

  /// Relit les données sans masquer celles déjà affichées.
  Future<void> liveReload();

  LiveSubscription? _liveSubscription;

  @override
  void initState() {
    super.initState();
    _liveSubscription = LiveRefreshScope.maybeOf(context)?.listen(
      topics: liveTopics,
      pollEvery: livePollEvery,
      reload: () async {
        if (mounted) await liveReload();
      },
    );
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }
}
