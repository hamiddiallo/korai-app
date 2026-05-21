import 'package:flutter/material.dart';

import '../../../../core/utils/consultation_format.dart';
import '../../domain/ai_case.dart';
import '../../domain/patient.dart';

class ConsultationHistoryList extends StatelessWidget {
  const ConsultationHistoryList({
    super.key,
    required this.consultations,
    this.patient,
    this.emptyMessage = 'Aucune consultation enregistrée pour ce dossier.',
    this.onOpenConsultation,
    this.onResumeDraft,
    this.onStartNew,
    this.showStartButton = true,
  });

  final List<AiCase> consultations;
  final Patient? patient;
  final String emptyMessage;
  final void Function(AiCase consultation)? onOpenConsultation;
  final void Function(AiCase draft)? onResumeDraft;
  final VoidCallback? onStartNew;
  final bool showStartButton;

  @override
  Widget build(BuildContext context) {
    if (consultations.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          if (showStartButton && onStartNew != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStartNew,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Nouvelle consultation'),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (patient != null) ...[
          Text(
            'Dossier : ${patient!.fullName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '${consultations.length} consultation${consultations.length > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
        ],
        ...consultations.map((consultation) {
          final isDraft = consultation.isDraft;
          final isCompleted = consultation.isCompleted;
          final color = isDraft
              ? Colors.orange
              : isCompleted
                  ? Colors.green
                  : const Color(0xFF006D77);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  isDraft ? Icons.edit_note : Icons.event_note_outlined,
                  color: color,
                  size: 22,
                ),
              ),
              title: Text(
                ConsultationFormat.formatDateTime(consultation.createdAt),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    ConsultationFormat.statusLabel(consultation.status),
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                  ),
                  if (consultation.summary.likelyDiagnosis != null &&
                      consultation.summary.likelyDiagnosis!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        consultation.summary.likelyDiagnosis!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                ],
              ),
              trailing: Icon(
                isDraft ? Icons.play_arrow_rounded : Icons.chevron_right,
                color: color,
              ),
              onTap: () {
                if (isDraft && onResumeDraft != null) {
                  onResumeDraft!(consultation);
                } else if (onOpenConsultation != null) {
                  onOpenConsultation!(consultation);
                }
              },
            ),
          );
        }),
        if (showStartButton && onStartNew != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onStartNew,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle consultation'),
          ),
        ],
      ],
    );
  }
}

void showConsultationDetailSheet(BuildContext context, AiCase consultation, {String? patientName}) {
  final summary = consultation.summary;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Consultation du ${ConsultationFormat.formatDateTime(consultation.createdAt)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (patientName != null) ...[
                  const SizedBox(height: 4),
                  Text(patientName, style: TextStyle(color: Colors.grey.shade700)),
                ],
                const Divider(height: 24),
                _DetailRow('Statut', ConsultationFormat.statusLabel(consultation.status)),
                _DetailRow('Dernière mise à jour', ConsultationFormat.formatDateTime(consultation.updatedAt)),
                _DetailRow('Diagnostic probable', summary.likelyDiagnosis ?? 'Non déterminé'),
                _DetailRow('Avis image', summary.imageOpinion ?? 'Non disponible'),
                _DetailRow('Avis symptômes', summary.ragOpinion ?? 'Non disponible'),
                _DetailRow('Confiance', summary.confidenceLabel),
                if (summary.warnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Alertes', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...summary.warnings.map((w) => Text('• $w', style: const TextStyle(fontSize: 13))),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text('$label :', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
