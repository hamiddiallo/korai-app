import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'notification_models.dart';
import 'notification_repository.dart';

class NotificationState {
  const NotificationState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final bool isLoading;

  NotificationState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifications de l'utilisateur. La relève périodique est faite par
/// `LiveRefresh` (premier plan seulement) ; chaque notification nouvelle est
/// signalée par [onNewNotifications] pour que les écrans concernés se relisent.
class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit({required NotificationRepository repository, this.onNewNotifications})
      : _repository = repository,
        super(const NotificationState());

  final NotificationRepository _repository;

  /// Notifications du serveur arrivées depuis la relève précédente.
  final void Function(List<AppNotification> fresh)? onNewNotifications;

  bool _started = false;

  /// Identifiants déjà vus ; `null` avant la première relève (celles qui
  /// existaient à la connexion ne sont pas « nouvelles »).
  Set<String>? _known;

  Future<void> start() async {
    if (_started) {
      await refresh();
      return;
    }
    _started = true;
    await _loadCached();
    await refresh();
  }

  Future<void> stop() async {
    _started = false;
    _known = null;
    // Vide le cache local : le cache de notifications est global à l'appareil,
    // il ne doit pas réapparaître pour l'utilisateur suivant (changement de compte).
    try {
      await _repository.clearLocal();
    } catch (_) {
      // Base indisponible : on ignore.
    }
    if (!isClosed) emit(const NotificationState());
  }

  Future<void> _loadCached() async {
    try {
      final items = await _repository.cached();
      final unread = await _repository.unreadCount();
      if (!isClosed) emit(state.copyWith(items: items, unreadCount: unread));
    } on MissingPluginException {
      // Base indisponible sur cette plateforme — ignoré.
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true));
    try {
      final items = await _repository.refresh();
      final unread = await _repository.unreadCount();
      _announceNew(items);
      if (!isClosed) {
        emit(state.copyWith(items: items, unreadCount: unread, isLoading: false));
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    await _repository.markRead(notification);
    await _loadCached();
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead();
    await _loadCached();
  }

  void _announceNew(List<AppNotification> items) {
    final server = items.where((n) => !n.isLocal).toList();
    final known = _known;
    _known = {...?known, for (final n in server) n.id};
    if (known == null) return;
    final fresh = server.where((n) => !known.contains(n.id)).toList();
    if (fresh.isNotEmpty) onNewNotifications?.call(fresh);
  }
}
