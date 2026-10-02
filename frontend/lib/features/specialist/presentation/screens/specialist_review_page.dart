import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/korai_enums.dart';
import '../../../../core/utils/consultation_format.dart';
import '../../../../core/utils/diagnosis_text.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/otoscopy_photo.dart';
import '../../../nurse/domain/ai_case.dart';
import '../../../nurse/presentation/widgets/ai_proposal_block.dart';
import '../../data/specialist_repository.dart';

enum _Section { clinical, ai, opinion }

/// Dossier d'une demande d'avis : données cliniques, proposition de l'IA et
/// avis du spécialiste. L'action principale reste sous le pouce :
/// « Prendre en charge », puis « Envoyer l'avis ».
class SpecialistReviewPage extends StatefulWidget {
  const SpecialistReviewPage({
    super.key,
    required this.repository,
    required this.item,
    required this.currentUserId,
    required this.onChanged,
  });

  final SpecialistRepository repository;
  final ExpertiseInboxItem item;
  final String? currentUserId;

  /// Appelé après une prise en charge ou un avis envoyé (rafraîchir la file).
  final VoidCallback onChanged;

  @override
  State<SpecialistReviewPage> createState() => _SpecialistReviewPageState();
}

class _SpecialistReviewPageState extends State<SpecialistReviewPage> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosis = TextEditingController();
  final _clinicalSummary = TextEditingController();
  final _recommendation = TextEditingController();
  final _comment = TextEditingController();

  AiCase? _case;
  bool _loading = true;
  Object? _loadError;
  bool _assigned = false;
  bool _takenByColleague = false;
  bool _sent = false;
  ExpertDecision _decision = ExpertDecision.validated;
  _Section _section = _Section.clinical;

  ExpertiseInboxItem get _item => widget.item;

  @override
  void initState() {
    super.initState();
    final me = widget.currentUserId;
    _assigned = _item.status == ExpertiseStatus.inReview && me != null && _item.assignedToUserId == me;
    _takenByColleague = _item.assignedToUserId != null && _item.assignedToUserId != me;
    _load();
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    _clinicalSummary.dispose();
    _recommendation.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final found = await widget.repository.findCase(_item.consultationId);
      if (!mounted) return;
      setState(() {
        _case = found;
        if (found != null && !_hasAi(found)) _decision = ExpertDecision.insufficient;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static bool _hasAi(AiCase c) => c.hasAiResult && !c.isAiFailed;

  bool get _dirty =>
      _clinicalSummary.text.trim().isNotEmpty ||
      _recommendation.text.trim().isNotEmpty ||
      _comment.text.trim().isNotEmpty ||
      (_decision == ExpertDecision.corrected && _diagnosis.text.trim().isNotEmpty);

  // ---------------- Actions ----------------

  Future<void> _takeCharge() async {
    try {
      await widget.repository.assign(_item.consultationId);
      if (!mounted) return;
      setState(() {
        _assigned = true;
        _section = _Section.opinion;
      });
      widget.onChanged();
      KSnack.success(context, 'Dossier pris en charge. Vous pouvez rédiger votre avis.');
    } catch (e) {
      if (!mounted) return;
      KSnack.error(context, e);
      widget.onChanged();
    }
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      KSnack.show(context, 'Complétez les champs signalés en rouge avant d’envoyer.', tone: KTone.warning);
      return;
    }
    final ok = await showKConfirm(
      context,
      title: 'Envoyer votre avis ?',
      message: 'Le soignant sera notifié immédiatement. Votre avis ne pourra plus être modifié ensuite.',
      confirmLabel: 'Envoyer l’avis',
    );
    if (!ok || !mounted) return;
    try {
      await widget.repository.submitReview(
        _item.consultationId,
        decision: _decision,
        comment: _comment.text.trim(),
        correctedLikelyDiagnosis: _decision == ExpertDecision.validated ? null : _diagnosis.text.trim(),
        correctedRecommendation: _recommendation.text.trim(),
        correctedClinicalSummary: _decision == ExpertDecision.validated ? null : _clinicalSummary.text.trim(),
      );
      if (!mounted) return;
      setState(() => _sent = true);
      widget.onChanged();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => KResultScreen(
            kind: KResultKind.success,
            title: 'Avis envoyé',
            message: 'Le soignant de ${_item.patientLabel} est notifié. Le dossier quitte votre file.',
            primaryLabel: 'Retour à la file',
            onPrimary: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    }
  }

  Future<void> _onPop(bool didPop) async {
    if (didPop) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showKConfirm(
      context,
      title: 'Quitter sans envoyer ?',
      message: 'Ce que vous avez saisi sera perdu. Le dossier reste pris en charge par vous.',
      confirmLabel: 'Quitter',
      cancelLabel: 'Continuer l’avis',
      destructive: true,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  // ---------------- Construction ----------------

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_item.patientLabel),
          Text(
            'Demande du ${ConsultationFormat.formatDateTime(_item.createdAt)}',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );

    if (_loading) {
      return Scaffold(appBar: appBar, body: const KLoadingView(message: 'Ouverture du dossier…'));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: appBar,
        body: KErrorView(title: 'Le dossier n’a pas pu être ouvert', error: _loadError!, onRetry: _load),
      );
    }
    final c = _case;
    if (c == null) {
      return Scaffold(
        appBar: appBar,
        body: KEmptyView(
          icon: Icons.search_off_rounded,
          title: 'Dossier introuvable',
          message: 'Il a peut-être été retiré de la file. Revenez à la file et actualisez-la.',
          actionLabel: 'Retour à la file',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    return PopScope(
      canPop: _sent || !_assigned,
      onPopInvokedWithResult: (didPop, _) => _onPop(didPop),
      child: Scaffold(
        appBar: appBar,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.sm),
              child: _Summary(item: _item, consultation: c),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.sm),
              child: KSegmented<_Section>(
                segments: const [
                  KSegment(value: _Section.clinical, label: 'Clinique'),
                  KSegment(value: _Section.ai, label: 'IA'),
                  KSegment(value: _Section.opinion, label: 'Votre avis'),
                ],
                value: _section,
                onChanged: (s) => setState(() => _section = s),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _section.index,
                children: [
                  _ClinicalSection(consultation: c),
                  _AiSection(consultation: c),
                  _opinionSection(c),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  Widget? _bottomBar() {
    if (_takenByColleague) return null;
    final k = context.k;
    final Widget action;
    if (!_assigned) {
      action = KAsyncButton(
        label: 'Prendre en charge',
        busyLabel: 'Prise en charge…',
        icon: Icons.assignment_ind_outlined,
        onPressed: _takeCharge,
      );
    } else if (_section != _Section.opinion) {
      action = FilledButton.icon(
        onPressed: () => setState(() => _section = _Section.opinion),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Rédiger mon avis'),
      );
    } else {
      action = KAsyncButton(
        label: 'Envoyer l’avis',
        busyLabel: 'Envoi de l’avis…',
        icon: Icons.send_rounded,
        onPressed: _send,
      );
    }
    return Container(
      decoration: BoxDecoration(color: k.surface, border: Border(top: BorderSide(color: k.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.gutter, KSpace.sm),
          child: SizedBox(width: double.infinity, child: action),
        ),
      ),
    );
  }

  Widget _opinionSection(AiCase c) {
    if (_takenByColleague) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xl),
        children: const [
          KBanner(
            tone: KTone.neutral,
            icon: Icons.lock_outline_rounded,
            title: 'Pris en charge par un confrère',
            message: 'Vous pouvez consulter ce dossier. Seul le spécialiste qui l’a pris en charge peut rendre l’avis.',
          ),
        ],
      );
    }
    if (!_assigned) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.lg, KSpace.gutter, KSpace.xl),
        children: const [
          KEmptyView(
            icon: Icons.assignment_ind_outlined,
            title: 'Prenez le dossier en charge',
            message:
                'Vos confrères verront qu’il est en cours d’examen. Vous pourrez ensuite rédiger et envoyer votre avis.',
            compact: true,
          ),
        ],
      );
    }

    final hasAi = _hasAi(c);
    final needsDiagnosis = _decision == ExpertDecision.corrected;
    final needsSummary = _decision != ExpertDecision.validated;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xl),
        children: [
          Text('Votre décision', style: context.text.titleMedium),
          const SizedBox(height: KSpace.xs),
          _DecisionTile(
            title: 'Valider la proposition de l’IA',
            subtitle: hasAi
                ? 'Le diagnostic proposé est correct : « ${DiagnosisText.headline(c.summary.likelyDiagnosis)} ».'
                : 'Indisponible : l’IA n’a pas produit de diagnostic pour ce dossier.',
            icon: Icons.check_circle_outline_rounded,
            selected: _decision == ExpertDecision.validated,
            enabled: hasAi,
            onTap: () => setState(() => _decision = ExpertDecision.validated),
          ),
          const SizedBox(height: KSpace.xs),
          _DecisionTile(
            title: 'Corriger le diagnostic',
            subtitle: 'Vous proposez un autre diagnostic et une synthèse.',
            icon: Icons.edit_outlined,
            selected: _decision == ExpertDecision.corrected,
            enabled: hasAi,
            onTap: () => setState(() => _decision = ExpertDecision.corrected),
          ),
          const SizedBox(height: KSpace.xs),
          _DecisionTile(
            title: 'Rendre un avis sans l’IA',
            subtitle: 'L’analyse IA est insuffisante : votre avis la remplace.',
            icon: Icons.person_outline_rounded,
            selected: _decision == ExpertDecision.insufficient,
            onTap: () => setState(() => _decision = ExpertDecision.insufficient),
          ),
          const SizedBox(height: KSpace.lg),
          if (_decision != ExpertDecision.validated) ...[
            TextFormField(
              controller: _diagnosis,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: needsDiagnosis ? 'Diagnostic corrigé *' : 'Diagnostic (facultatif)',
              ),
              validator: needsDiagnosis ? (v) => KValidators.required(v, 'Diagnostic corrigé') : null,
            ),
            const SizedBox(height: KSpace.sm),
          ],
          if (needsSummary) ...[
            TextFormField(
              controller: _clinicalSummary,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Synthèse clinique *',
                helperText: 'Ce que vous retenez de l’examen et des symptômes.',
                alignLabelWithHint: true,
              ),
              validator: (v) => KValidators.required(v, 'Synthèse clinique'),
            ),
            const SizedBox(height: KSpace.sm),
          ],
          TextFormField(
            controller: _recommendation,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Conduite à tenir (facultatif)',
              helperText: 'Traitement, examens ou orientation conseillés au soignant.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: KSpace.sm),
          TextFormField(
            controller: _comment,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Commentaire pour le soignant (facultatif)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.item, required this.consultation});

  final ExpertiseInboxItem item;
  final AiCase consultation;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return KCard(
      padding: const EdgeInsets.all(KSpace.sm),
      child: Row(
        children: [
          KInitialsAvatar(name: item.patientLabel, size: 44),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: KEarTag(side: consultation.earSide, long: true)),
                    Text('  ·  ', style: context.text.bodySmall),
                    Icon(Icons.schedule_rounded, size: 14, color: k.inkMuted),
                    const SizedBox(width: 3),
                    Text(
                      'attend depuis ${ConsultationFormat.formatWaiting(item.waiting)}',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                KUrgencyPill(level: consultation.urgency, prefix: 'Urgence', dense: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicalSection extends StatelessWidget {
  const _ClinicalSection({required this.consultation});

  final AiCase consultation;

  @override
  Widget build(BuildContext context) {
    final note = consultation.expertiseReview?.summaryNote?.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xl),
      children: [
        if (note != null && note.isNotEmpty) ...[
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.forum_outlined, size: 18, color: context.k.inkMuted),
                    const SizedBox(width: 6),
                    Text('Note du soignant', style: context.text.titleMedium),
                  ],
                ),
                const SizedBox(height: KSpace.xs),
                Text(note, style: context.text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: KSpace.sm),
        ],
        if (consultation.images.isNotEmpty)
          OtoscopyPhotos(images: consultation.images)
        else if (consultation.status != 'DRAFT')
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.sm),
            child: KBanner(
              tone: KTone.neutral,
              icon: Icons.no_photography_outlined,
              message: 'Pas de photo du tympan pour cette consultation : l’avis porte sur les données cliniques.',
            ),
          ),
        ClinicalFactsCard(consultation: consultation),
        const SizedBox(height: KSpace.sm),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Consultation', style: context.text.titleMedium),
              const SizedBox(height: KSpace.xs),
              KInfoRow(label: 'Date', value: ConsultationFormat.formatDateTime(consultation.createdAt)),
              KInfoRow(label: 'Oreille', value: consultation.earSide.label),
              KInfoRow(label: 'Urgence', value: KUrgency.label(consultation.urgency)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection({required this.consultation});

  final AiCase consultation;

  @override
  Widget build(BuildContext context) {
    final c = consultation;
    final available = c.hasAiResult && !c.isAiFailed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xl),
      children: [
        if (!available)
          const KBanner(
            tone: KTone.warning,
            icon: Icons.cloud_off_rounded,
            title: 'Analyse IA indisponible',
            message: 'L’IA n’a pas pu analyser cette consultation. Fondez votre avis sur les données cliniques.',
          )
        else ...[
          AiProposalBlock(summary: c.summary),
          const SizedBox(height: KSpace.sm),
          Text(
            'Proposition d’aide à la décision : elle ne remplace pas votre examen.',
            style: context.text.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: KCard(
          onTap: enabled ? onTap : null,
          padding: const EdgeInsets.all(KSpace.sm),
          color: selected ? k.lagoon : null,
          borderColor: selected ? k.brand : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? k.brand : k.inkMuted),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: KSpace.xs),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? k.brand : k.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
