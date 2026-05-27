import 'dart:async';
import 'package:flutter/services.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'sync_outbox_dao.dart';
import 'sync_service.dart';

class SyncState {
  const SyncState({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncedAt,
    this.errorMessage,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  SyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    int? failedCount,
    Object? lastSyncedAt = _unset,
    Object? errorMessage = _unset,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      lastSyncedAt: identical(lastSyncedAt, _unset)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();

class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required SyncService syncService,
    Connectivity? connectivity,
    SyncOutboxDao? outboxDao,
  })  : _syncService = syncService,
        _connectivity = connectivity ?? Connectivity(),
        _outboxDao = outboxDao ?? SyncOutboxDao.instance,
        super(const SyncState());

  final SyncService _syncService;
  final Connectivity _connectivity;
  final SyncOutboxDao _outboxDao;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      await synchronizeNow();
      return;
    }
    _started = true;

    try {
      final initialResults = await _connectivity.checkConnectivity();
      await _handleConnectivityChange(initialResults);
      _connectivitySubscription = _connectivity.onConnectivityChanged
          .listen(_handleConnectivityChange);
    } on MissingPluginException {
      // Plugin non disponible sur cette plateforme (ex: desktop, web).
      // On suppose qu'on est en ligne pour ne pas bloquer l'interface.
      if (!isClosed) emit(state.copyWith(isOnline: true));
    } catch (e) {
      // Toute autre erreur d'initialisation : on reste en mode dégradé.
      if (!isClosed) emit(state.copyWith(isOnline: false));
    }

    await refreshCounts();
  }

  Future<void> stop() async {
    _started = false;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    if (!isClosed) {
      emit(state.copyWith(isSyncing: false));
    }
  }

  Future<void> refreshCounts() async {
    try {
      final pending = await _outboxDao.countPending();
      final failed = await _outboxDao.countFailed();
      if (!isClosed) {
        emit(state.copyWith(pendingCount: pending, failedCount: failed));
      }
    } on MissingPluginException {
      // Base de données non disponible sur cette plateforme — on ignore.
    } catch (_) {
      // Toute autre erreur de lecture — on ignore silencieusement.
    }
  }

  Future<void> synchronizeNow() async {
    if (state.isSyncing || !state.isOnline) return;

    emit(state.copyWith(isSyncing: true, errorMessage: null));
    try {
      final summary = await _syncService.synchronizePending();
      final failed = await _outboxDao.countFailed();
      if (!isClosed) {
        emit(
          state.copyWith(
            isSyncing: false,
            pendingCount: summary.pending,
            failedCount: failed,
            lastSyncedAt: DateTime.now(),
            errorMessage: null,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSyncing: false,
            errorMessage: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    if (!isClosed) {
      emit(state.copyWith(isOnline: isOnline));
    }
    if (isOnline) {
      await synchronizeNow();
    }
    await refreshCounts();
  }

  @override
  Future<void> close() async {
    await _connectivitySubscription?.cancel();
    return super.close();
  }
}
