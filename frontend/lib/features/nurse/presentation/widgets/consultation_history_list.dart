import 'package:flutter/material.dart';

import '../../../../core/domain/korai_enums.dart';
import '../../../../core/utils/consultation_format.dart';
import '../../domain/ai_case.dart';
import '../../domain/patient.dart';

typedef ConsultationPatientNameResolver = String? Function(AiCase consultation);

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
  });

  final List<AiCase> consultations;
  final Patient? patient;
  final ConsultationPatientNameResolver? patientNameFor;
  final String emptyMessage;
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
          final patientName = patient?.fullName ?? patientNameFor?.call(consultation);
          return ConsultationHistoryEntry(
            consultation: consultation,
            patientName: patientName,
            onResumeDraft: onResumeDraft,
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

class ConsultationHistoryEntry extends StatelessWidget {
  const ConsultationHistoryEntry({
    super.key,
    required this.consultation,
    this.patientName,
    this.onResumeDraft,
  });

  final AiCase consultation;
  final String? patientName;
  final void Function(AiCase draft)? onResumeDraft;

  @override
  Widget build(BuildContext context) {
    final isDraft = consultation.isDraft;
    final color = _statusColor(consultation);

    if (isDraft) {
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
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(Icons.edit_note, color: color, size: 22),
          ),
          title: Text(
            ConsultationFormat.formatDateTime(consultation.createdAt),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (patientName != null) ...[
                const SizedBox(height: 4),
                Text(patientName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 4),
              Text(
                '${ConsultationFormat.statusLabel(consultation.status)} · Brouillon à reprendre',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          trailing: Icon(Icons.play_arrow_rounded, color: color),
          onTap: onResumeDraft == null ? null : () => onResumeDraft!(consultation),
        ),
      );
    }

    final hasAiDetails = consultation.isCompleted ||
        consultation.status == ConsultationStatus.pendingAi.value ||
        consultation.status == ConsultationStatus.pendingSpecialistReview.value;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(Icons.event_note_outlined, color: color, size: 22),
          ),
          title: Text(
            ConsultationFormat.formatDateTime(consultation.createdAt),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (patientName != null) ...[
                const SizedBox(height: 4),
                Text(patientName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 4),
              Text(
                ConsultationFormat.statusLabel(consultation.status),
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                hasAiDetails ? 'Déplier pour voir le compte-rendu' : 'Aucun diagnostic IA disponible',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          children: hasAiDetails
              ? [
                  ConsultationDiagnosticDetails(consultation: consultation),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Diagnostic en cours ou non généré.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  Color _statusColor(AiCase consultation) {
    if (consultation.isDraft) return Colors.orange;
    if (consultation.isCompleted) return Colors.green;
    return const Color(0xFF006D77);
  }
}

/// Sections repliables du compte-rendu (évite d'afficher tout le texte d'un coup).
class ConsultationDiagnosticDetails extends StatelessWidget {
  const ConsultationDiagnosticDetails({super.key, required this.consultation});

  final AiCase consultation;

  @override
  Widget build(BuildContext context) {
    final summary = consultation.summary;
    final sections = <Widget>[
      _ExpandableDetailSection(
        title: 'Informations',
        icon: Icons.info_outline,
        children: [
          _DetailRow('Statut', ConsultationFormat.statusLabel(consultation.status)),
          _DetailRow('Oreille', ConsultationFormat.earSideLabel(consultation.earSide)),
          _DetailRow('Mise à jour', ConsultationFormat.formatDateTime(consultation.updatedAt)),
        ],
      ),
      if (_hasText(summary.likelyDiagnosis) || summary.confidenceLabel != AiConfidenceLabel.unknown)
        _ExpandableDetailSection(
          title: 'Synthèse diagnostique',
          icon: Icons.medical_information_outlined,
          children: [
            if (_hasText(summary.likelyDiagnosis))
              _DetailRow('Diagnostic probable', summary.likelyDiagnosis!),
            _DetailRow('Confiance', summary.confidenceLabel.value),
          ],
        ),
      if (_hasText(summary.imageOpinion))
        _ExpandableDetailSection(
          title: 'Avis image',
          icon: Icons.image_outlined,
          children: [_DetailParagraph(summary.imageOpinion!)],
        ),
      if (_hasText(summary.ragOpinion))
        _ExpandableDetailSection(
          title: 'Avis symptômes (RAG)',
          icon: Icons.article_outlined,
          children: [_DetailParagraph(summary.ragOpinion!)],
        ),
      if (consultation.symptomLabels.isNotEmpty ||
          consultation.medicalHistoryLabels.isNotEmpty ||
          consultation.touchCheckLabels.isNotEmpty)
        _ExpandableDetailSection(
          title: 'Données cliniques saisies',
          icon: Icons.checklist_outlined,
          children: [
            if (consultation.symptomLabels.isNotEmpty)
              _DetailRow('Symptômes', consultation.symptomLabels.join(', ')),
            if (consultation.medicalHistoryLabels.isNotEmpty)
              _DetailRow('Antécédents', consultation.medicalHistoryLabels.join(', ')),
            if (consultation.touchCheckLabels.isNotEmpty)
              _DetailRow('Toucher', consultation.touchCheckLabels.join(', ')),
          ],
        ),
      if (summary.warnings.isNotEmpty)
        _ExpandableDetailSection(
          title: 'Alertes (${summary.warnings.length})',
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange.shade800,
          children: summary.warnings.map((w) => _DetailBullet(w)).toList(),
        ),
      if (summary.sources.isNotEmpty)
        _ExpandableDetailSection(
          title: 'Sources (${summary.sources.length})',
          icon: Icons.menu_book_outlined,
          children: summary.sources.map((s) => _DetailBullet(s)).toList(),
        ),
    ];

    return Column(children: sections);
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

class _ExpandableDetailSection extends StatelessWidget {
  const _ExpandableDetailSection({
    required this.title,
    required this.icon,
    required this.children,
    this.iconColor,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        leading: Icon(icon, size: 20, color: iconColor ?? const Color(0xFF006D77)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              '$label :',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _DetailParagraph extends StatelessWidget {
  const _DetailParagraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
    );
  }
}

class _DetailBullet extends StatelessWidget {
  const _DetailBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

/// Feuille modale avec le même système de sections repliables (usage optionnel).
void showConsultationDetailSheet(BuildContext context, AiCase consultation, {String? patientName}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consultation du ${ConsultationFormat.formatDateTime(consultation.createdAt)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (patientName != null) ...[
                        const SizedBox(height: 4),
                        Text(patientName, style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ConsultationDiagnosticDetails(consultation: consultation),
              ],
            ),
          );
        },
      );
    },
  );
}
