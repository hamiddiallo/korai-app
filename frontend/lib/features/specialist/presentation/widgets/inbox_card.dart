import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/korai_enums.dart';
import '../../../../core/utils/consultation_format.dart';
import '../../data/specialist_repository.dart';

/// Demande d'avis dans la file : liseré d'urgence, patient, oreille, attente,
/// symptômes et proposition de l'IA. Toute la carte ouvre le dossier.
class InboxCard extends StatelessWidget {
  const InboxCard({
    super.key,
    required this.item,
    required this.isMine,
    required this.takenByColleague,
    required this.onTap,
  });

  final ExpertiseInboxItem item;
  final bool isMine;
  final bool takenByColleague;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final stripe = item.urgency == null ? k.line : KUrgency.color(context, item.urgency);
    final ai = item.aiDiagnosisDisplay;
    final symptoms = item.symptomLabels;
    final symptomText = symptoms.isEmpty
        ? null
        : symptoms.length <= 3
            ? symptoms.join(', ')
            : '${symptoms.take(3).join(', ')} +${symptoms.length - 3}';

    return Opacity(
      opacity: takenByColleague ? 0.72 : 1,
      child: KCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: stripe),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KSpace.sm, KSpace.sm, KSpace.xs, KSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          KInitialsAvatar(name: item.patientLabel, size: 38),
                          const SizedBox(width: KSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.patientLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Flexible(child: KEarTag(side: item.earSide)),
                                    Text('  ·  ', style: context.text.bodySmall),
                                    Icon(Icons.schedule_rounded, size: 14, color: k.inkMuted),
                                    const SizedBox(width: 3),
                                    Text(
                                      ConsultationFormat.formatWaiting(item.waiting),
                                      style: context.text.bodySmall?.copyWith(fontFamily: KFonts.mono),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          KUrgencyPill(level: item.urgency, dense: true),
                        ],
                      ),
                      if (symptomText != null) ...[
                        const SizedBox(height: KSpace.xs),
                        Text(
                          symptomText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            ai == null ? Icons.cloud_off_rounded : Icons.auto_awesome_rounded,
                            size: 16,
                            color: ai == null ? k.inkMuted : k.aquaInk,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ai == null
                                  ? 'Analyse IA indisponible'
                                  : '$ai · confiance ${KLabels.confidence(item.aiConfidence)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(
                                color: ai == null ? k.inkMuted : k.aquaInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KSpace.xs),
                      _statusPill(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: KSpace.xs),
                child: Icon(Icons.chevron_right_rounded, color: k.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill() {
    if (isMine) {
      return const KPill(
          label: 'Pris en charge par vous', icon: Icons.edit_note_rounded, tone: KTone.info, dense: true);
    }
    if (takenByColleague) {
      return const KPill(label: 'Pris en charge par un confrère', icon: Icons.lock_outline_rounded, dense: true);
    }
    if (item.status == ExpertiseStatus.pending) {
      return const KPill(label: 'À prendre en charge', icon: Icons.inbox_outlined, tone: KTone.brand, dense: true);
    }
    return KPill(label: KLabels.expertiseStatus(item.status.value), dense: true);
  }
}
