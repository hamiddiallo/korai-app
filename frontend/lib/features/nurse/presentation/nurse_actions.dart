import '../domain/ai_case.dart';
import '../domain/patient.dart';

/// Onglets de l'espace soignant (index de la barre de navigation).
class NurseTab {
  const NurseTab._();

  static const today = 0;
  static const patients = 1;
  static const newConsultation = 2;
  static const history = 3;
  static const assistant = 4;
}

/// Actions de navigation partagées par les écrans du soignant.
class NurseActions {
  const NurseActions({
    required this.startConsultation,
    required this.openPatient,
    required this.openConsultation,
    required this.openProfile,
    required this.goToTab,
    required this.reviewPendingPatient,
  });

  final void Function({Patient? patient, String? prefill}) startConsultation;
  final void Function(Patient patient) openPatient;
  final void Function(AiCase consultation) openConsultation;
  final void Function() openProfile;
  final void Function(int tab, {bool focusSearch}) goToTab;

  /// Ouvre la fiche d'un compte patient à valider.
  final void Function(Patient patient) reviewPendingPatient;
}
