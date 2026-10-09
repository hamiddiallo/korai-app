import 'package:flutter/foundation.dart';

import '../../../core/domain/korai_enums.dart';
import '../../../core/refresh/live_refresh.dart';
import '../data/nurse_repository.dart';
import '../domain/ai_case.dart';
import '../domain/patient.dart';

/// Données de travail du soignant (patients et consultations), partagées par
/// tous ses écrans. Chaque écran écoute ce modèle : une relance, une demande
/// d'avis ou l'avis du spécialiste se reflète partout sans rechargement manuel.
class NurseWorkspace extends ChangeNotifier {
  NurseWorkspace(this.repository);

  final NurseRepository repository;

  List<Patient> patients = const [];
  List<AiCase> cases = const [];
  bool loading = false;
  bool loadedOnce = false;
  Object? error;

  late final _refresh = SerialRefresh(_fetch);

  /// Changements faits sur l'appareil pendant une lecture : elle est refaite
  /// pour ne pas les écraser avec des données plus anciennes.
  int _localChanges = 0;

  /// Relit patients et consultations ; les données affichées restent en place
  /// pendant la lecture (relectures automatiques invisibles).
  Future<void> refresh() => _refresh();

  Future<void> _fetch() async {
    loading = true;
    notifyListeners();
    try {
      List<Patient> freshPatients;
      List<AiCase>? serverCases;
      Object? casesError;
      int seen;
      do {
        seen = _localChanges;
        // Les patients ont leur propre repli hors ligne (cache de l'appareil).
        final patientsFuture = repository.listPatients();
        try {
          serverCases = await repository.listCases();
          casesError = null;
        } catch (e) {
          // Hors ligne : on garde les consultations déjà chargées, l'erreur est
          // signalée, et celles saisies sur l'appareil restent visibles.
          serverCases = null;
          casesError = e;
        }
        freshPatients = await patientsFuture;
      } while (seen != _localChanges);
      final unsent = await repository.listUnsentConsultations().catchError((_) => <AiCase>[]);
      final known = serverCases ?? cases.where((c) => !c.isLocalOnly).toList();
      patients = freshPatients;
      // Les consultations pas encore envoyées apparaissent aussi (dossier,
      // historique), marquées « À envoyer ».
      cases = [...unsent, ...known].sortedByNewest();
      error = casesError;
      loadedOnce = true;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void upsertCase(AiCase updated) {
    _localChanges++;
    final index = cases.indexWhere((c) => c.id == updated.id);
    final next = [...cases];
    if (index >= 0) {
      next[index] = updated;
    } else {
      next.insert(0, updated);
    }
    cases = next.sortedByNewest();
    notifyListeners();
  }

  Patient? patientById(String? id) {
    if (id == null) return null;
    for (final p in patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  String? patientNameFor(AiCase c) => patientById(c.patientId)?.fullName;

  List<AiCase> casesFor(String patientId) => cases.forPatient(patientId).sortedByNewest();

  AiCase? caseById(String id) {
    for (final c in cases) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Patient> get pendingValidation => patients.where((p) => !p.isValidated).toList();

  /// Patients triés par dernière consultation (les plus récents d'abord).
  List<Patient> get patientsByRecency {
    DateTime last(Patient p) {
      final list = casesFor(p.id);
      return list.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : (DateTime.tryParse(list.first.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0));
    }

    final copy = [...patients.where((p) => p.isValidated)];
    copy.sort((a, b) => last(b).compareTo(last(a)));
    return copy;
  }

  // ---------------- Classement des consultations ----------------

  /// Demande une action du soignant : analyse à relancer ou brouillon.
  static bool needsAction(AiCase c) => c.isAiFailed || c.isDraft || c.upload == LocalUpload.failed;

  /// En attente d'un tiers (envoi, analyse en cours, avis demandé).
  static bool isWaiting(AiCase c) =>
      c.upload == LocalUpload.pending ||
      (c.upload == LocalUpload.none &&
          (c.status == ConsultationStatus.pendingAi.value ||
              c.status == ConsultationStatus.pendingSpecialistReview.value));

  static bool isDone(AiCase c) => c.isCompleted;

  /// Avis spécialiste reçu dans les 7 derniers jours.
  static bool isRecentOpinion(AiCase c) {
    if (c.status != ConsultationStatus.specialistCompleted.value) return false;
    final at = DateTime.tryParse(c.updatedAt);
    return at != null && DateTime.now().difference(at.toLocal()).inDays < 7;
  }

  /// Liste « À traiter » de l'accueil : actions d'abord, puis avis récents,
  /// puis demandes en attente.
  List<AiCase> get todayQueue => [
        ...cases.where(needsAction),
        ...cases.where(isRecentOpinion),
        ...cases.where((c) => c.status == ConsultationStatus.pendingSpecialistReview.value),
      ];

  // ---------------- Actions ----------------

  Future<AiCase> requestExpertise(AiCase c, {String? summaryNote}) async {
    final updated = await repository.requestExpertise(c.id, summaryNote: summaryNote ?? c.clinicalNotes);
    upsertCase(updated);
    return updated;
  }

  Future<AiCase> retryDiagnosis(AiCase c) async {
    final updated = await repository.retryDiagnosis(c.id);
    upsertCase(updated);
    return updated;
  }

  /// Accords recueillis auprès du patient (réseau requis).
  Future<Patient> updateConsents(Patient p, {required bool ai, required bool teleExpertise}) async {
    final updated = await repository.updateConsents(p.id, consentForAi: ai, consentForTeleExpertise: teleExpertise);
    _localChanges++;
    patients = [for (final existing in patients) existing.id == updated.id ? updated : existing];
    notifyListeners();
    return updated;
  }

  Future<Patient> validatePatient(Patient p) async {
    final validated = await repository.validatePatient(p.id);
    await refresh();
    return validated;
  }
}
