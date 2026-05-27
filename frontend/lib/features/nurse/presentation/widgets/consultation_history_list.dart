import 'package:flutter/material.dart';

import '../../../../core/domain/korai_enums.dart';
import '../../../../core/utils/consultation_format.dart';
import '../../domain/ai_case.dart';
import '../../domain/patient.dart';
import 'expertise_request_panel.dart';

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
    this.forPatient = false,
    this.onRequestExpertise,
    this.onConsultationUpdated,
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
          final patientName =
              patient?.fullName ?? patientNameFor?.call(consultation);
          return ConsultationHistoryEntry(
            consultation: consultation,
            patientName: patientName,
            onResumeDraft: onResumeDraft,
            forPatient: forPatient,
            onRequestExpertise: onRequestExpertise,
            onConsultationUpdated: onConsultationUpdated,
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
    this.forPatient = false,
    this.onRequestExpertise,
    this.onConsultationUpdated,
  });

  final AiCase consultation;
  final String? patientName;
  final void Function(AiCase draft)? onResumeDraft;
  final bool forPatient;
  final ExpertiseRequestCallback? onRequestExpertise;
  final void Function(AiCase updated)? onConsultationUpdated;

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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                Text(patientName!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 4),
              Text(
                '${ConsultationFormat.statusLabel(consultation.status)} · Brouillon à reprendre',
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          trailing: Icon(Icons.play_arrow_rounded, color: color),
          onTap:
              onResumeDraft == null ? null : () => onResumeDraft!(consultation),
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
                Text(patientName!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 4),
              Text(
                ConsultationFormat.statusLabel(consultation.status),
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                hasAiDetails
                    ? 'Déplier pour voir le compte-rendu'
                    : 'Aucun diagnostic IA disponible',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          children: hasAiDetails
              ? [
                  ConsultationDiagnosticDetails(
                    consultation: consultation,
                    patientName: patientName,
                    forPatient: forPatient,
                    onRequestExpertise: onRequestExpertise,
                    onConsultationUpdated: onConsultationUpdated,
                  ),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Diagnostic en cours ou non généré.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
  const ConsultationDiagnosticDetails({
    super.key,
    required this.consultation,
    this.patientName,
    this.forPatient = false,
    this.onRequestExpertise,
    this.onConsultationUpdated,
  });

  final AiCase consultation;
  final String? patientName;
  final bool forPatient;
  final ExpertiseRequestCallback? onRequestExpertise;
  final void Function(AiCase updated)? onConsultationUpdated;

  @override
  Widget build(BuildContext context) {
    final effective = consultation.effectiveSummary;
    final hideForPatient =
        forPatient && !consultation.patientCanSeeClinicalDetails;

    if (hideForPatient) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          effective?.patientStatusLabel ??
              'Votre consultation est en cours d\'analyse par un spécialiste.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      );
    }

    final summary = consultation.summary;
    final expertise = consultation.expertiseReview;
    final sections = <Widget>[
      _ExpandableDetailSection(
        title: 'Informations patient',
        subtitle: patientName ?? 'Déplier pour voir',
        icon: Icons.person_outline,
        children: _patientInfoChildren(),
      ),
      _ExpandableDetailSection(
        title: 'Informations cliniques',
        subtitle: _clinicalSubtitle(),
        icon: Icons.medical_information_outlined,
        children: _clinicalInfoChildren(),
      ),
      _ExpandableDetailSection(
        title: 'Réponse de l\'IA',
        subtitle: summary.likelyDiagnosis?.trim().isNotEmpty == true
            ? summary.likelyDiagnosis!
            : 'Voir le détail',
        icon: Icons.psychology_outlined,
        children: _aiResponseChildren(summary),
      ),
      if (expertise != null)
        _ExpandableDetailSection(
          title: 'Réponse de l\'expert',
          subtitle: _expertSubtitle(expertise),
          icon: Icons.verified_user_outlined,
          iconColor: const Color(0xFF006D77),
          children: _expertResponseChildren(expertise),
        ),
      if (!forPatient && onRequestExpertise != null)
        ExpertiseRequestPanel(
          consultation: consultation,
          onRequest: onRequestExpertise!,
          onUpdated: onConsultationUpdated,
        ),
    ];

    return Column(children: sections);
  }

  List<Widget> _patientInfoChildren() {
    return [
      if (patientName != null) _DetailRow('Patient', patientName!),
      _DetailRow(
          'Date', ConsultationFormat.formatDateTime(consultation.createdAt)),
      _DetailRow(
          'Oreille', ConsultationFormat.earSideLabel(consultation.earSide)),
      _DetailRow('Urgence', consultation.urgency.value),
      _DetailRow('Statut', ConsultationFormat.statusLabel(consultation.status)),
      _DetailRow('Mise à jour',
          ConsultationFormat.formatDateTime(consultation.updatedAt)),
      if (_hasText(consultation.clinicalNotes))
        _DetailParagraph(consultation.clinicalNotes!),
    ];
  }

  String _clinicalSubtitle() {
    final parts = <String>[];
    if (consultation.symptomLabels.isNotEmpty) {
      parts.add('${consultation.symptomLabels.length} symptôme(s)');
    }
    if (consultation.medicalHistoryLabels.isNotEmpty) {
      parts.add('${consultation.medicalHistoryLabels.length} antécédent(s)');
    }
    return parts.isEmpty ? 'Déplier pour voir' : parts.join(' · ');
  }

  List<Widget> _clinicalInfoChildren() {
    final children = <Widget>[];
    if (consultation.symptomLabels.isNotEmpty) {
      children
          .add(_DetailRow('Symptômes', consultation.symptomLabels.join(', ')));
    }
    if (consultation.medicalHistoryLabels.isNotEmpty) {
      children.add(_DetailRow(
          'Antécédents', consultation.medicalHistoryLabels.join(', ')));
    }
    if (consultation.touchCheckLabels.isNotEmpty) {
      for (var i = 0; i < consultation.touchCheckLabels.length; i++) {
        final label = consultation.touchCheckLabels[i];
        final id = i < consultation.touchCheckIds.length
            ? consultation.touchCheckIds[i]
            : null;
        final obs = id != null ? consultation.touchObservations[id] : null;
        children.add(
          _DetailRow(
            'Toucher',
            obs != null && obs.isNotEmpty ? '$label — $obs' : label,
          ),
        );
      }
    }
    if (children.isEmpty && _hasText(consultation.symptoms)) {
      children.add(_DetailParagraph(consultation.symptoms!));
    }
    if (children.isEmpty) {
      children.add(
        Text(
          'Aucune donnée clinique structurée.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      );
    }
    return children;
  }

  List<Widget> _aiResponseChildren(AiSummary summary) {
    final children = <Widget>[
      _DetailRow(
          'Diagnostic probable', summary.likelyDiagnosis ?? 'Non déterminé'),
      _DetailRow('Confiance', summary.confidenceLabel.value),
    ];
    if (_hasText(summary.imageOpinion)) {
      children.add(_DetailBlock('Avis image', summary.imageOpinion!));
    }
    if (_hasText(summary.ragOpinion)) {
      children.add(_DetailBlock('Avis symptômes (RAG)', summary.ragOpinion!));
    }
    if (summary.warnings.isNotEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 4),
        child: Text('Alertes',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ));
      children.addAll(summary.warnings.map((w) => _DetailBullet(w)));
    }
    return children;
  }

  String _expertSubtitle(ExpertiseReview expertise) {
    if (expertise.status == ExpertiseStatus.completed &&
        expertise.decision != null) {
      return expertise.decision!.label;
    }
    return switch (expertise.status) {
      ExpertiseStatus.pending => 'En attente de prise en charge',
      ExpertiseStatus.inReview => 'Analyse en cours',
      ExpertiseStatus.completed => 'Terminée',
    };
  }

  List<Widget> _expertResponseChildren(ExpertiseReview expertise) {
    final children = <Widget>[
      _DetailRow('Statut expertise', _expertStatusLabel(expertise.status)),
    ];

    if (_hasText(expertise.summaryNote)) {
      children.add(_DetailBlock('Note à l\'escalade', expertise.summaryNote!));
    }

    if (expertise.status != ExpertiseStatus.completed ||
        expertise.decision == null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'L\'avis du spécialiste sera affiché ici une fois la revue terminée.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
      );
      return children;
    }

    children.add(_DetailRow('Décision', expertise.decision!.label));

    switch (expertise.decision!) {
      case ExpertDecision.validated:
        children.add(
          _DetailRow(
            'Diagnostic retenu',
            consultation.summary.likelyDiagnosis ?? 'Non déterminé',
          ),
        );
        children.add(
          _DetailRow('Confiance', 'HIGH (validation experte)'),
        );
      case ExpertDecision.corrected:
      case ExpertDecision.insufficient:
        if (_hasText(expertise.correctedLikelyDiagnosis)) {
          children.add(
              _DetailRow('Diagnostic', expertise.correctedLikelyDiagnosis!));
        } else if (expertise.decision == ExpertDecision.insufficient) {
          children.add(_DetailRow('Diagnostic', 'Indéterminé'));
        }
        if (_hasText(expertise.correctedClinicalSummary)) {
          children.add(_DetailBlock(
              'Synthèse clinique', expertise.correctedClinicalSummary!));
        }
    }

    if (_hasText(expertise.correctedRecommendation)) {
      children.add(
          _DetailRow('Recommandation', expertise.correctedRecommendation!));
    }
    if (_hasText(expertise.comment)) {
      children.add(_DetailBlock('Commentaire', expertise.comment!));
    }
    if (_hasText(expertise.reviewedAt)) {
      children.add(_DetailRow('Date de l\'avis',
          ConsultationFormat.formatDateTime(expertise.reviewedAt)));
    }

    return children;
  }

  String _expertStatusLabel(ExpertiseStatus status) => switch (status) {
        ExpertiseStatus.pending => 'En attente',
        ExpertiseStatus.inReview => 'En cours de revue',
        ExpertiseStatus.completed => 'Terminée',
      };

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

class _ExpandableDetailSection extends StatelessWidget {
  const _ExpandableDetailSection({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
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
        leading:
            Icon(icon, size: 20, color: iconColor ?? const Color(0xFF006D77)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
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
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child:
                Text(value, style: const TextStyle(fontSize: 13, height: 1.35)),
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

class _DetailBlock extends StatelessWidget {
  const _DetailBlock(this.label, this.text);

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ),
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
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

/// Feuille modale avec le même système de sections repliables (usage optionnel).
void showConsultationDetailSheet(BuildContext context, AiCase consultation,
    {String? patientName}) {
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (patientName != null) ...[
                        const SizedBox(height: 4),
                        Text(patientName,
                            style: TextStyle(color: Colors.grey.shade700)),
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
