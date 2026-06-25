import 'dart:async';
import 'package:flutter/services.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../offline/offline_models.dart';
import 'sync_outbox_dao.dart';
import 'sync_service.dart';

/// Élément en échec de synchronisation, présenté à l'utilisateur (libellé +
/// cause), avec son identifiant d'outbox pour le réessai ciblé.
class FailedSyncItem {
  const FailedSyncItem({
    required this.localId,
    required this.title,
    required this.subtitle,
    this.error,
  });

  final String localId;
  final String title;
  final String subtitle;
  final String? error;
}

class SyncState {
  const SyncState({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.failedItems = const [],
    this.lastSyncedAt,
    this.errorMessage,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final List<FailedSyncItem> failedItems;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  SyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    int? failedCount,
    List<FailedSyncItem>? failedItems,
    Object? lastSyncedAt = _unset,
    Object? errorMessage = _unset,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      failedItems: failedItems ?? this.failedItems,
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
  Timer? _retryTimer;
  bool _started = false;

  /// Période de relance automatique : couvre les entrées dont le `next_retry_at`
  /// arrive à échéance sans qu'un changement de connectivité ne se produise.
  static const _retryInterval = Duration(seconds: 90);

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

    _startRetryTimer();
    await refreshCounts();
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryInterval, (_) {
      if (state.isOnline && !state.isSyncing && state.pendingCount > 0) {
        unawaited(synchronizeNow());
      }
    });
  }

  Future<void> stop() async {
    _started = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    if (!isClosed) {
      emit(state.copyWith(isSyncing: false));
    }
  }

  Future<void> refreshCounts() async {
    try {
      final pending = await _outboxDao.countPending();
      final failedEntries = await _outboxDao.listFailed();
      if (!isClosed) {
        emit(state.copyWith(
          pendingCount: pending,
          failedCount: failedEntries.length,
          failedItems: failedEntries.map(_toFailedItem).toList(),
        ));
      }
    } on MissingPluginException {
      // Base de données non disponible sur cette plateforme — on ignore.
    } catch (_) {
      // Toute autre erreur de lecture — on ignore silencieusement.
    }
  }

  /// Remet en file un élément en échec précis, puis tente la synchronisation.
  Future<void> retryItem(String localId) async {
    await _outboxDao.requeueFailed(localId);
    await synchronizeNow();
    await refreshCounts();
  }

  /// Remet en file tous les éléments en échec, puis tente la synchronisation.
  /// Sert aussi de relance générale (couvre les éléments en attente).
  Future<void> retryAll() async {
    await _outboxDao.requeueAllFailed();
    await synchronizeNow();
    await refreshCounts();
  }

  FailedSyncItem _toFailedItem(SyncOutboxEntry entry) {
    String title;
    String subtitle;
    if (entry.operation == OutboxOperation.createPatient.value) {
      final firstName = entry.payload['firstName']?.toString() ?? '';
      final lastName = entry.payload['lastName']?.toString() ?? '';
      final name = '$firstName $lastName'.trim();
      title = name.isEmpty ? 'Patient' : name;
      subtitle = 'Création de patient';
    } else if (entry.operation == OutboxOperation.submitDiagnosis.value) {
      final diagnosis = entry.payload['diagnosisPayload'];
      final narrative =
          diagnosis is Map ? diagnosis['symptoms']?.toString() ?? '' : '';
      title = _patientNameFromNarrative(narrative) ?? 'Consultation';
      subtitle = 'Analyse de consultation';
    } else {
      title = 'Élément à synchroniser';
      subtitle = entry.operation;
    }
    return FailedSyncItem(
      localId: entry.localId,
      title: title,
      subtitle: subtitle,
      error: entry.lastError,
    );
  }

  String? _patientNameFromNarrative(String narrative) {
    for (final line in narrative.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Patient:')) {
        final value = trimmed.substring('Patient:'.length).trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  Future<void> synchronizeNow() async {
    if (state.isSyncing || !state.isOnline) return;

    emit(state.copyWith(isSyncing: true, errorMessage: null));
    try {
      final summary = await _syncService.synchronizePending();
      final failedEntries = await _outboxDao.listFailed();
      if (!isClosed) {
        emit(
          state.copyWith(
            isSyncing: false,
            pendingCount: summary.pending,
            failedCount: failedEntries.length,
            failedItems: failedEntries.map(_toFailedItem).toList(),
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
    _retryTimer?.cancel();
    await _connectivitySubscription?.cancel();
    return super.close();
  }
}
