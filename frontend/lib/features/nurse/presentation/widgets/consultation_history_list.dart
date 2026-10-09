import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../domain/ai_case.dart';
import '../../domain/patient.dart';
import '../screens/consultation_detail_page.dart';
import 'consultation_card.dart';
import 'expertise_request_panel.dart';

typedef ConsultationPatientNameResolver = String? Function(AiCase consultation);

/// Liste de consultations (soignant ou patient). Chaque ligne ouvre le détail
/// de la consultation en page.
class ConsultationHistoryList extends StatelessWidget {
  const ConsultationHistoryList({
    super.key,
    required this.consultations,
    this.patient,
    this.patientNameFor,
    this.emptyMessage = 'Aucune consultation enregistrée pour ce dossier.',
    this.onResumeDraft,
    this.onStartNew,
    this.showStartButton = true,
    this.forPatient = false,
    this.onRequestExpertise,
    this.onConsultationUpdated,
    this.onRetryFailed,
    this.updates,
    this.latest,
  });

  final List<AiCase> consultations;
  final Patient? patient;
  final ConsultationPatientNameResolver? patientNameFor;
  final String emptyMessage;
  final void Function(AiCase draft)? onResumeDraft;
  final VoidCallback? onStartNew;
  final bool showStartButton;
  final bool forPatient;
  final ExpertiseRequestCallback? onRequestExpertise;
  final void Function(AiCase updated)? onConsultationUpdated;

  /// Relance l'analyse IA d'une consultation en échec ; renvoie la
  /// consultation mise à jour.
  final Future<AiCase> Function(AiCase consultation)? onRetryFailed;

  /// Source à jour des consultations : le détail ouvert suit ses relectures.
  final Listenable? updates;
  final CaseLookup? latest;

  static Future<void> openDetail(
    BuildContext context,
    AiCase consultation, {
    String? patientName,
    bool forPatient = false,
    ExpertiseRequestCallback? onRequestExpertise,
    ValueChanged<AiCase>? onConsultationUpdated,
    Future<AiCase> Function(AiCase)? onRetry,
    ValueChanged<AiCase>? onResumeDraft,
    Listenable? updates,
    CaseLookup? latest,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsultationDetailPage(
          consultation: consultation,
          patientName: patientName,
          forPatient: forPatient,
          onRequestExpertise: onRequestExpertise,
          onConsultationUpdated: onConsultationUpdated,
          onRetry: onRetry,
          updates: updates,
          latest: latest,
          onResumeDraft: onResumeDraft == null
              ? null
              : (draft) {
                  Navigator.of(context).pop();
                  onResumeDraft(draft);
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (consultations.isEmpty) {
      return KEmptyView(
        icon: Icons.event_note_outlined,
        title: 'Aucune consultation',
        message: emptyMessage,
        actionLabel: showStartButton && onStartNew != null ? 'Nouvelle consultation' : null,
        onAction: showStartButton ? onStartNew : null,
        compact: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in consultations) ...[
          ConsultationCard(
            consultation: c,
            patientName: patient?.fullName ?? patientNameFor?.call(c),
            showDiagnosis: !forPatient || c.patientCanSeeClinicalDetails,
            onTap: () => openDetail(
              context,
              c,
              patientName: patient?.fullName ?? patientNameFor?.call(c),
              forPatient: forPatient,
              onRequestExpertise: onRequestExpertise,
              onConsultationUpdated: onConsultationUpdated,
              onRetry: onRetryFailed,
              onResumeDraft: onResumeDraft,
              updates: updates,
              latest: latest,
            ),
          ),
          const SizedBox(height: KSpace.xs),
        ],
        if (showStartButton && onStartNew != null) ...[
          const SizedBox(height: KSpace.xs),
          FilledButton.icon(
            onPressed: onStartNew,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouvelle consultation'),
          ),
        ],
      ],
    );
  }
}
