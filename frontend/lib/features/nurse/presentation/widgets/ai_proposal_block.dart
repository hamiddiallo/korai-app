import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/korai_enums.dart';
import '../../../../core/utils/consultation_format.dart';
import '../../../../core/utils/diagnosis_text.dart';
import '../../domain/ai_case.dart';

/// Proposition de l'IA, structurée : diagnostic, confiance, avis sur l'image
/// et sur les symptômes, alertes, sources. Filet aqua = c'est l'IA qui parle.
class AiProposalBlock extends StatelessWidget {
  const AiProposalBlock({super.key, required this.summary, this.compact = false});

  final AiSummary summary;
  final bool compact;

  double? get _confidenceValue => switch (summary.confidenceLabel) {
        AiConfidenceLabel.high => 0.85,
        AiConfidenceLabel.medium => 0.6,
        AiConfidenceLabel.low => 0.3,
        AiConfidenceLabel.unknown => null,
      };

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final diagnosis = summary.likelyDiagnosis?.trim();
    final value = _confidenceValue;
    // Anciennes réponses : sources enregistrées « [object Object] » avant le correctif serveur.
    final sources = summary.sources.where((s) => s.trim().isNotEmpty && s != '[object Object]').toList();
    return KAuthorBlock.ai(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (diagnosis == null || diagnosis.isEmpty) ? 'Pas de diagnostic proposé' : DiagnosisText.headline(diagnosis),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleLarge,
          ),
          if (!compact && DiagnosisText.hasDetails(diagnosis)) FullReport(text: diagnosis!),
          const SizedBox(height: KSpace.sm),
          Row(
            children: [
              Text('Confiance', style: context.text.bodySmall),
              const Spacer(),
              Text(
                KLabels.confidence(summary.confidenceLabel.value),
                style: context.text.labelMedium?.copyWith(color: k.aquaInk),
              ),
            ],
          ),
          if (value != null) ...[
            const SizedBox(height: 4),
            Semantics(
              label: 'Confiance ${KLabels.confidence(summary.confidenceLabel.value)}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: k.surfaceAlt,
                  color: k.aqua,
                ),
              ),
            ),
          ],
          if (!compact) ...[
            if (_has(summary.imageOpinion)) _Opinion(title: 'Sur l’image', text: summary.imageOpinion!),
            // L'avis RAG reprend souvent mot pour mot le diagnostic : déjà lisible via « Lire l'analyse complète ».
            if (_has(summary.ragOpinion) && summary.ragOpinion!.trim() != diagnosis)
              _Opinion(title: 'Sur les symptômes', text: summary.ragOpinion!),
          ],
          if (summary.warnings.isNotEmpty) ...[
            const SizedBox(height: KSpace.md),
            Text('Points de vigilance', style: context.text.titleSmall),
            const SizedBox(height: 4),
            for (final w in summary.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.warning_amber_rounded, size: 18, color: k.warning),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(w, style: context.text.bodyMedium)),
                  ],
                ),
              ),
          ],
          if (!compact && sources.isNotEmpty) ...[
            const SizedBox(height: KSpace.md),
            Text('Sources', style: context.text.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in sources.take(6))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: k.line),
                    ),
                    child: Text(s, style: context.text.labelSmall?.copyWith(color: k.inkMuted)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;
}

/// Rapport complet de l'IA, replié par défaut : sections numérotées
/// (« Causes probables », « Signes associés »…) affichées comme telles.
class FullReport extends StatefulWidget {
  const FullReport({super.key, required this.text});

  final String text;

  @override
  State<FullReport> createState() => _FullReportState();
}

class _FullReportState extends State<FullReport> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final sections = DiagnosisText.sections(widget.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: KMotion.of(context, KMotion.base),
          curve: KMotion.enter,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in sections) ...[
                      const SizedBox(height: KSpace.sm),
                      if (s.title != null) Text(s.title!, style: context.text.titleSmall),
                      if (s.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(s.body, style: context.text.bodyMedium),
                      ],
                    ],
                  ],
                ),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 40)),
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          label: Text(_open ? 'Réduire l’analyse' : 'Lire l’analyse complète'),
        ),
      ],
    );
  }
}

class _Opinion extends StatelessWidget {
  const _Opinion({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final sections = DiagnosisText.sections(text);
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleSmall),
          for (final s in sections) ...[
            const SizedBox(height: 4),
            if (s.title != null) Text(s.title!, style: context.text.labelLarge),
            if (s.body.isNotEmpty) Text(s.body, style: context.text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Avis du spécialiste : filet encre et coche, c'est un humain qui a validé.
class SpecialistOpinionBlock extends StatelessWidget {
  const SpecialistOpinionBlock({super.key, required this.consultation});

  final AiCase consultation;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final e = consultation.expertiseReview;
    if (e == null) return const SizedBox.shrink();

    if (e.status != ExpertiseStatus.completed || e.decision == null) {
      return KBanner(
        tone: KTone.info,
        icon: Icons.schedule_rounded,
        title: e.status == ExpertiseStatus.inReview ? 'Spécialiste en train d’examiner' : 'Avis demandé',
        message: 'L’avis du spécialiste s’affichera ici dès qu’il sera rendu. Vous serez notifié·e.',
      );
    }

    final decision = e.decision!;
    final diagnosis = switch (decision) {
      ExpertDecision.validated => DiagnosisText.headline(consultation.summary.likelyDiagnosis, fallback: ''),
      _ => e.correctedLikelyDiagnosis,
    };
    return KAuthorBlock.specialist(
      trailing: e.reviewedAt == null
          ? null
          : Text(
              ConsultationFormat.formatDate(e.reviewedAt),
              style: context.text.labelSmall?.copyWith(color: k.inkMuted),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KPill(
            label: decision.label,
            icon: decision == ExpertDecision.validated ? Icons.check_rounded : Icons.edit_rounded,
            tone: decision == ExpertDecision.validated ? KTone.success : KTone.warning,
            dense: true,
          ),
          const SizedBox(height: KSpace.sm),
          Text(
            (diagnosis == null || diagnosis.trim().isEmpty) ? 'Diagnostic à préciser' : diagnosis,
            style: context.text.titleLarge,
          ),
          if (_has(e.correctedClinicalSummary)) _Opinion(title: 'Synthèse', text: e.correctedClinicalSummary!),
          if (_has(e.correctedRecommendation)) _Opinion(title: 'Conduite à tenir', text: e.correctedRecommendation!),
          if (_has(e.comment)) _Opinion(title: 'Commentaire', text: e.comment!),
        ],
      ),
    );
  }

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;
}

/// Ce qui a été observé : symptômes, antécédents, examen au toucher, notes.
class ClinicalFactsCard extends StatelessWidget {
  const ClinicalFactsCard({super.key, required this.consultation});

  final AiCase consultation;

  @override
  Widget build(BuildContext context) {
    final c = consultation;
    final touch = <String>[];
    for (var i = 0; i < c.touchCheckLabels.length; i++) {
      final id = i < c.touchCheckIds.length ? c.touchCheckIds[i] : null;
      final obs = id == null ? null : c.touchObservations[id];
      touch.add(obs != null && obs.isNotEmpty ? '${c.touchCheckLabels[i]} : $obs' : c.touchCheckLabels[i]);
    }
    final hasStructured = c.symptomLabels.isNotEmpty || c.medicalHistoryLabels.isNotEmpty || touch.isNotEmpty;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ce qui a été observé', style: context.text.titleMedium),
          const SizedBox(height: KSpace.xs),
          if (!hasStructured && (c.symptoms?.trim().isNotEmpty ?? false))
            Text(c.symptoms!, style: context.text.bodyMedium)
          else if (!hasStructured)
            Text('Aucune donnée clinique saisie.', style: context.text.bodyMedium?.copyWith(color: context.k.inkMuted))
          else ...[
            KInfoRow(label: 'Symptômes', value: c.symptomLabels.isEmpty ? 'Aucun' : c.symptomLabels.join(', ')),
            KInfoRow(
                label: 'Antécédents',
                value: c.medicalHistoryLabels.isEmpty ? 'Aucun' : c.medicalHistoryLabels.join(', ')),
            KInfoRow(label: 'Au toucher', value: touch.isEmpty ? 'Non réalisé' : touch.join('\n')),
          ],
          if (c.clinicalNotes?.trim().isNotEmpty ?? false) KInfoRow(label: 'Notes', value: c.clinicalNotes!.trim()),
        ],
      ),
    );
  }
}
