import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../domain/ai_case.dart';
import '../nurse_workspace.dart';
import '../widgets/ai_proposal_block.dart';
import '../../../../core/widgets/otoscopy_photo.dart';

/// Résultat d'une consultation qui vient d'être analysée : urgence, proposition
/// de l'IA, et l'action suivante (demander un avis ou terminer).
class ConsultationResultPage extends StatefulWidget {
  const ConsultationResultPage({
    super.key,
    required this.consultation,
    required this.patientName,
    required this.workspace,
    this.infoMessage,
  });

  final AiCase consultation;
  final String patientName;
  final NurseWorkspace workspace;

  /// Message d'information (ex. réponse reprise hors ligne).
  final String? infoMessage;

  @override
  State<ConsultationResultPage> createState() => _ConsultationResultPageState();
}

class _ConsultationResultPageState extends State<ConsultationResultPage> {
  late AiCase _case = widget.consultation;

  Future<void> _retry() async {
    try {
      final updated = await widget.workspace.retryDiagnosis(_case);
      if (!mounted) return;
      setState(() => _case = updated);
      if (updated.isAiFailed) {
        KSnack.show(context, 'L’analyse n’a toujours pas abouti. Réessayez un peu plus tard depuis l’historique.',
            tone: KTone.warning);
      }
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    }
  }

  Future<void> _requestOpinion() async {
    try {
      final updated = await widget.workspace.requestExpertise(_case);
      if (!mounted) return;
      setState(() => _case = updated);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => KResultScreen(
            kind: KResultKind.success,
            title: 'Demande d’avis envoyée',
            message:
                'Un spécialiste ORL va examiner le dossier de ${widget.patientName}. Vous serez notifié·e dès sa réponse.',
            primaryLabel: 'Retour à l’accueil',
            onPrimary: () => Navigator.of(ctx).popUntil((route) => route.isFirst),
          ),
        ),
      );
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final c = _case;
    final failed = c.isAiFailed;
    final tone = k.tone(KUrgency.tone(c.urgency));

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: tone.bg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.xs, KSpace.sm),
                child: Row(
                  children: [
                    Icon(KUrgency.icon(c.urgency), color: tone.accent),
                    const SizedBox(width: KSpace.xs),
                    Expanded(
                      child: Text(
                        'Urgence ${KUrgency.label(c.urgency).toLowerCase()}',
                        style: context.text.titleSmall?.copyWith(color: tone.fg),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer le résultat',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: tone.fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, KSpace.xl),
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: widget.patientName.isEmpty ? 'Patient' : widget.patientName),
                    const TextSpan(text: '  ·  '),
                    WidgetSpan(alignment: PlaceholderAlignment.middle, child: KEarTag(side: c.earSide)),
                  ]),
                  style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
                ),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: Text(failed ? 'Analyse non aboutie' : 'Résultat de l’analyse',
                      style: context.text.headlineMedium),
                ),
                const SizedBox(height: KSpace.md),
                if (widget.infoMessage != null) ...[
                  KBanner(tone: KTone.info, icon: Icons.cloud_off_rounded, message: widget.infoMessage!),
                  const SizedBox(height: KSpace.md),
                ],
                if (failed)
                  KCard(
                    borderColor: k.warning,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cloud_off_rounded, color: k.warning),
                            const SizedBox(width: KSpace.xs),
                            Expanded(
                                child: Text('Le service d’analyse n’a pas répondu', style: context.text.titleSmall)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${c.aiErrorDisplay} La consultation est enregistrée : vous pouvez relancer maintenant ou plus tard depuis l’historique.',
                          style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
                        ),
                        const SizedBox(height: KSpace.sm),
                        KAsyncButton(
                            label: 'Relancer l’analyse',
                            busyLabel: 'Analyse en cours…',
                            icon: Icons.refresh_rounded,
                            onPressed: _retry),
                      ],
                    ),
                  )
                else ...[
                  AiProposalBlock(summary: c.summary),
                  if (c.expertiseReview != null) ...[
                    const SizedBox(height: KSpace.md),
                    SpecialistOpinionBlock(consultation: c),
                  ],
                ],
                const SizedBox(height: KSpace.md),
                if (c.images.isNotEmpty) OtoscopyPhotos(images: c.images),
                ClinicalFactsCard(consultation: c),
                const SizedBox(height: KSpace.md),
                Text(
                  'La proposition de l’IA aide à décider. Elle ne remplace pas votre examen.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: k.surface, border: Border(top: BorderSide(color: k.line))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.gutter, KSpace.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!failed && c.canRequestExpertise)
                      KAsyncButton(
                        label: 'Demander un avis spécialiste',
                        busyLabel: 'Envoi de la demande…',
                        icon: Icons.send_rounded,
                        onPressed: _requestOpinion,
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(failed ? 'Relancer plus tard' : 'Terminer la consultation'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
