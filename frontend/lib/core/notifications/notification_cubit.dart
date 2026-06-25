import 'dart:async';

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

class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit({required NotificationRepository repository})
      : _repository = repository,
        super(const NotificationState());

  final NotificationRepository _repository;
  Timer? _pollTimer;
  bool _started = false;

  /// Fréquence de relève serveur (polling), comme la synchronisation.
  static const _pollInterval = Duration(seconds: 90);

  Future<void> start() async {
    if (_started) {
      await refresh();
      return;
    }
    _started = true;
    await _loadCached();
    await refresh();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  Future<void> stop() async {
    _started = false;
    _pollTimer?.cancel();
    _pollTimer = null;
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
      if (!isClosed) {
        emit(state.copyWith(
            items: items, unreadCount: unread, isLoading: false));
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

  @override
  Future<void> close() async {
    _pollTimer?.cancel();
    return super.close();
  }
}
