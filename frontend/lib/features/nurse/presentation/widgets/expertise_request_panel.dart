import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/korai_enums.dart';
import '../../domain/ai_case.dart';

typedef ExpertiseRequestCallback = Future<AiCase> Function(
  AiCase consultation, {
  String? summaryNote,
});

/// Demande d'avis spécialiste depuis une consultation analysée.
class ExpertiseRequestPanel extends StatelessWidget {
  const ExpertiseRequestPanel({
    super.key,
    required this.consultation,
    required this.onRequest,
    this.onUpdated,
    this.summaryNote,
  });

  final AiCase consultation;
  final ExpertiseRequestCallback onRequest;
  final ValueChanged<AiCase>? onUpdated;
  final String? summaryNote;

  Future<void> _submit(BuildContext context) async {
    try {
      final updated = await onRequest(consultation, summaryNote: summaryNote);
      onUpdated?.call(updated);
      if (context.mounted) {
        KSnack.success(context, 'Demande d’avis envoyée. Vous serez notifié·e dès la réponse du spécialiste.');
      }
    } catch (e) {
      if (context.mounted) KSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = consultation;

    if (c.expertiseReview?.status == ExpertiseStatus.completed ||
        c.status == ConsultationStatus.specialistCompleted.value) {
      return const SizedBox.shrink();
    }

    if (c.expertiseInProgress) {
      return const Padding(
        padding: EdgeInsets.only(top: KSpace.sm),
        child: KBanner(
          tone: KTone.info,
          icon: Icons.schedule_rounded,
          title: 'Avis demandé',
          message: 'Un spécialiste ORL va examiner ce dossier. Vous serez notifié·e dès sa réponse.',
        ),
      );
    }

    if (!c.canRequestExpertise) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: KSpace.sm),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Besoin d’un second avis ?', style: context.text.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Un spécialiste ORL confirme ou corrige la proposition de l’IA, sans déplacement du patient.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: KSpace.sm),
            KAsyncButton(
              label: 'Demander un avis spécialiste',
              busyLabel: 'Envoi de la demande…',
              icon: Icons.send_rounded,
              onPressed: () => _submit(context),
            ),
          ],
        ),
      ),
    );
  }
}
