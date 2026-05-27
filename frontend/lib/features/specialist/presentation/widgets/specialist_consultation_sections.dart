import 'package:flutter/material.dart';

import '../../../../core/utils/consultation_format.dart';
import '../../../nurse/domain/ai_case.dart';
import 'specialist_expandable_section.dart';

/// Sections dossier pour l'écran spécialiste (sans doublon snapshot / expertise).
class SpecialistConsultationSections extends StatelessWidget {
  const SpecialistConsultationSections({
    super.key,
    required this.consultation,
    required this.patientLabel,
  });

  final AiCase consultation;
  final String patientLabel;

  @override
  Widget build(BuildContext context) {
    final summary = consultation.summary;
    final aiDiag = summary.likelyDiagnosis?.trim() ?? 'Non déterminé';

    return Column(
      children: [
        SpecialistExpandableSection(
          title: 'Informations patient',
          subtitle: patientLabel,
          icon: Icons.person_outline,
          children: _patientInfoChildren(),
        ),
        SpecialistExpandableSection(
          title: 'Informations cliniques',
          subtitle: _clinicalSubtitle(),
          icon: Icons.medical_information_outlined,
          children: _clinicalInfoChildren(),
        ),
        SpecialistExpandableSection(
          title: 'Diagnostic de l\'IA',
          subtitle: aiDiag,
          icon: Icons.psychology_outlined,
          children: _aiDiagnosisChildren(summary),
        ),
      ],
    );
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

  List<Widget> _patientInfoChildren() {
    return [
      _DetailRow('Patient', patientLabel),
      _DetailRow(
          'Date', ConsultationFormat.formatDateTime(consultation.createdAt)),
      _DetailRow(
          'Oreille', ConsultationFormat.earSideLabel(consultation.earSide)),
      _DetailRow('Urgence', consultation.urgency.value),
      _DetailRow('Statut', ConsultationFormat.statusLabel(consultation.status)),
      if (_hasText(consultation.clinicalNotes))
        _DetailBlock('Notes dossier', consultation.clinicalNotes!),
    ];
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
    if (consultation.symptomLabels.isEmpty &&
        consultation.medicalHistoryLabels.isEmpty &&
        consultation.touchCheckLabels.isEmpty &&
        _hasText(consultation.symptoms)) {
      children.add(_DetailBlock('Synthèse saisie', consultation.symptoms!));
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

  List<Widget> _aiDiagnosisChildren(AiSummary summary) {
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
      children.addAll(summary.warnings.map((w) => _Bullet(w)));
    }
    if (summary.sources.isNotEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 4),
        child: Text('Sources',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ));
      children.addAll(summary.sources.map((s) => _Bullet(s)));
    }
    return children;
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
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
            width: 110,
            child: Text(
              '$label :',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 12, height: 1.35))),
        ],
      ),
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

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12, height: 1.35))),
        ],
      ),
    );
  }
}
