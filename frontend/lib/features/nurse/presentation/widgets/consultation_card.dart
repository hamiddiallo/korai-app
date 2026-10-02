import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/diagnosis_text.dart';
import '../../domain/ai_case.dart';

/// Ligne de consultation : bloc de date, patient, heure, oreille, statut et
/// urgence. Toute la carte s'ouvre au toucher.
class ConsultationCard extends StatelessWidget {
  const ConsultationCard({
    super.key,
    required this.consultation,
    this.patientName,
    this.onTap,
    this.showDiagnosis = true,
  });

  final AiCase consultation;
  final String? patientName;
  final VoidCallback? onTap;
  final bool showDiagnosis;

  static String time(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String? waitingLabel(AiCase c) {
    final requested = DateTime.tryParse(c.expertiseReview?.requestedAt ?? '');
    if (requested == null) return null;
    final d = DateTime.now().difference(requested.toLocal());
    if (d.inMinutes < 60) return 'depuis ${d.inMinutes.clamp(1, 59)} min';
    if (d.inHours < 48) return 'depuis ${d.inHours} h';
    return 'depuis ${d.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final c = consultation;
    final date = DateTime.tryParse(c.createdAt);
    final diagnosis = c.hasAiResult ? DiagnosisText.headline(c.displayDiagnosis) : null;
    final waiting = c.expertiseInProgress ? waitingLabel(c) : null;
    final old = date != null && DateTime.now().difference(date.toLocal()).inDays > 30;

    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(KSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KDateBlock(date: date, muted: old),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName ?? 'Consultation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(time(c.createdAt), style: context.text.bodySmall?.copyWith(fontFamily: KFonts.mono)),
                    Text('  ·  ', style: context.text.bodySmall),
                    Flexible(child: KEarTag(side: c.earSide)),
                  ],
                ),
                if (showDiagnosis && diagnosis != null && diagnosis.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    diagnosis,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: c.status == 'SPECIALIST_COMPLETED' ? k.ink : k.aquaInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: KSpace.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (c.upload == LocalUpload.pending)
                      const KPill(
                          label: 'À envoyer', icon: Icons.cloud_upload_outlined, tone: KTone.warning, dense: true)
                    else if (c.upload == LocalUpload.failed)
                      const KPill(
                          label: 'Envoi refusé', icon: Icons.cloud_off_outlined, tone: KTone.danger, dense: true)
                    else
                      KConsultationStatusPill(status: c.status, dense: true),
                    if (c.urgency.value == 'HIGH' || c.urgency.value == 'MEDIUM')
                      KUrgencyPill(level: c.urgency, dense: true),
                    if (waiting != null) KPill(label: waiting, icon: Icons.schedule_rounded, dense: true),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 4),
              child: Icon(Icons.chevron_right_rounded, color: k.inkMuted),
            ),
        ],
      ),
    );
  }
}
