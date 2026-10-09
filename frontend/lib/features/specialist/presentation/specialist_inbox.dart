import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/design/design.dart';
import '../../../core/domain/korai_enums.dart';
import '../../../core/refresh/live_refresh.dart';
import '../data/specialist_repository.dart';

/// État partagé de la télé-expertise : la file (dossiers que personne n'a
/// pris) et « Mes dossiers » (pris en charge par moi, avis à rendre), triés par
/// urgence puis ancienneté. Relue automatiquement ; une prise en charge ou un
/// avis envoyé s'y reflète aussitôt, sans attendre la relecture.
class SpecialistInbox extends ChangeNotifier {
  SpecialistInbox(this.repository, {required this.currentUserId});

  final SpecialistRepository repository;
  final String? currentUserId;

  List<ExpertiseInboxItem> items = const [];
  bool loading = false;
  bool loadedOnce = false;
  Object? error;

  late final _refresh = SerialRefresh(_fetch);

  /// Changements faits sur l'appareil : une lecture commencée avant eux est
  /// périmée et refaite (sinon un dossier pris réapparaîtrait dans la file).
  int _localChanges = 0;

  Future<void> refresh() => _refresh();

  Future<void> _fetch() async {
    loading = true;
    notifyListeners();
    try {
      List<ExpertiseInboxItem> fresh;
      int seen;
      do {
        seen = _localChanges;
        fresh = await repository.listInbox();
      } while (seen != _localChanges);
      items = [...fresh]..sort((a, b) {
          final byUrgency = KUrgency.rank(a.urgency).compareTo(KUrgency.rank(b.urgency));
          return byUrgency != 0 ? byUrgency : a.createdAt.compareTo(b.createdAt);
        });
      error = null;
      loadedOnce = true;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  ExpertiseInboxItem? find(String consultationId) {
    for (final item in items) {
      if (item.consultationId == consultationId) return item;
    }
    return null;
  }

  /// Prise en charge réussie : le dossier quitte la file pour « Mes dossiers ».
  void markTakenByMe(String consultationId) {
    final me = currentUserId;
    if (me == null) return;
    _localChanges++;
    items = [
      for (final item in items)
        item.consultationId == consultationId
            ? item.copyWith(assignedToUserId: me, status: ExpertiseStatus.inReview)
            : item,
    ];
    notifyListeners();
    unawaited(refresh());
  }

  /// Avis envoyé : le dossier quitte « Mes dossiers ».
  void remove(String consultationId) {
    _localChanges++;
    items = items.where((item) => item.consultationId != consultationId).toList();
    notifyListeners();
    unawaited(refresh());
  }

  bool isMine(ExpertiseInboxItem i) => currentUserId != null && i.assignedToUserId == currentUserId;

  bool isTakenByColleague(ExpertiseInboxItem i) => i.assignedToUserId != null && !isMine(i);

  /// Dossiers que personne n'a encore pris en charge.
  List<ExpertiseInboxItem> get queue => items.where((i) => i.assignedToUserId == null).toList();

  /// Dossiers que j'ai pris en charge et dont l'avis reste à envoyer.
  List<ExpertiseInboxItem> get mine => items.where(isMine).toList();

  int get urgentCount => queue.where((i) => i.urgency == UrgencyLevel.high).length;

  int get toTakeCount => queue.length;

  Duration? get averageWaiting {
    final waits = queue.map((i) => i.waiting).whereType<Duration>().toList();
    if (waits.isEmpty) return null;
    final total = waits.fold<int>(0, (sum, d) => sum + d.inMinutes);
    return Duration(minutes: total ~/ waits.length);
  }
}
