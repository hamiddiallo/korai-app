import 'package:flutter/foundation.dart';

import '../../../core/design/design.dart';
import '../../../core/domain/korai_enums.dart';
import '../data/specialist_repository.dart';

/// État partagé de la file d'expertise : chargée une fois, relue à la
/// demande, triée par urgence puis ancienneté.
class SpecialistInbox extends ChangeNotifier {
  SpecialistInbox(this.repository, {required this.currentUserId});

  final SpecialistRepository repository;
  final String? currentUserId;

  List<ExpertiseInboxItem> items = const [];
  bool loading = false;
  bool loadedOnce = false;
  Object? error;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final fresh = await repository.listInbox();
      fresh.sort((a, b) {
        final byUrgency = KUrgency.rank(a.urgency).compareTo(KUrgency.rank(b.urgency));
        return byUrgency != 0 ? byUrgency : a.createdAt.compareTo(b.createdAt);
      });
      items = fresh;
      error = null;
      loadedOnce = true;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool isMine(ExpertiseInboxItem i) => currentUserId != null && i.assignedToUserId == currentUserId;

  bool isTakenByColleague(ExpertiseInboxItem i) => i.assignedToUserId != null && !isMine(i);

  /// Dossiers que je peux prendre ou que j'ai déjà pris.
  List<ExpertiseInboxItem> get queue => items.where((i) => !isTakenByColleague(i)).toList();

  List<ExpertiseInboxItem> get mine => items.where(isMine).toList();

  int get urgentCount => queue.where((i) => i.urgency == UrgencyLevel.high).length;

  int get toTakeCount => items.where((i) => i.status == ExpertiseStatus.pending).length;

  Duration? get averageWaiting {
    final waits = queue.map((i) => i.waiting).whereType<Duration>().toList();
    if (waits.isEmpty) return null;
    final total = waits.fold<int>(0, (sum, d) => sum + d.inMinutes);
    return Duration(minutes: total ~/ waits.length);
  }
}
