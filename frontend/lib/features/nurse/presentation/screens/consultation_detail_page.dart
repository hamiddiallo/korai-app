import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/korai_enums.dart';
import '../../../../core/utils/consultation_format.dart';
import '../../domain/ai_case.dart';
import '../widgets/ai_proposal_block.dart';
import '../widgets/expertise_request_panel.dart';
import '../../../../core/widgets/otoscopy_photo.dart';

/// Version à jour d'une consultation (`null` : inconnue de la source).
typedef CaseLookup = AiCase? Function(String consultationId);

/// Détail d'une consultation, en page (plus d'accordéons imbriqués).
/// Partagé par le soignant et le patient. Avec [updates] et [latest], la page
/// suit les relectures : l'avis du spécialiste y apparaît dès qu'il arrive.
class ConsultationDetailPage extends StatefulWidget {
  const ConsultationDetailPage({
    super.key,
    required this.consultation,
    this.patientName,
    this.forPatient = false,
    this.onRequestExpertise,
    this.onConsultationUpdated,
    this.onRetry,
    this.onResumeDraft,
    this.updates,
    this.latest,
  });

  final AiCase consultation;
  final String? patientName;
  final bool forPatient;
  final ExpertiseRequestCallback? onRequestExpertise;
  final ValueChanged<AiCase>? onConsultationUpdated;
  final Future<AiCase> Function(AiCase consultation)? onRetry;
  final ValueChanged<AiCase>? onResumeDraft;

  /// Prévient quand la source des consultations a été relue.
  final Listenable? updates;
  final CaseLookup? latest;

  @override
  State<ConsultationDetailPage> createState() => _ConsultationDetailPageState();
}

class _ConsultationDetailPageState extends State<ConsultationDetailPage> {
  late AiCase _case = widget.consultation;

  @override
  void initState() {
    super.initState();
    widget.updates?.addListener(_onUpdates);
  }

  @override
  void dispose() {
    widget.updates?.removeListener(_onUpdates);
    super.dispose();
  }

  void _onUpdates() {
    final fresh = widget.latest?.call(_case.id);
    if (fresh != null && !identical(fresh, _case) && mounted) setState(() => _case = fresh);
  }

  void _updated(AiCase c) {
    setState(() => _case = c);
    widget.onConsultationUpdated?.call(c);
  }

  Future<void> _retry() async {
    try {
      final updated = await widget.onRetry!(_case);
      if (!mounted) return;
      _updated(updated);
      if (updated.isAiFailed) {
        KSnack.show(context, 'L’analyse n’a toujours pas abouti. Réessayez un peu plus tard.', tone: KTone.warning);
      } else {
        KSnack.success(context, 'Analyse terminée.');
      }
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _case;
    final k = context.k;
    final hidden = widget.forPatient && !c.patientCanSeeClinicalDetails;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Consultation'),
            Text(
              ConsultationFormat.formatDateTime(c.createdAt),
              style: context.text.bodySmall?.copyWith(fontFamily: KFonts.mono),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xxl),
        children: [
          KCard(
            child: Row(
              children: [
                KInitialsAvatar(name: widget.patientName ?? 'Patient', size: 48),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.patientName ?? 'Patient', style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      KEarTag(side: c.earSide, long: true),
                      const SizedBox(height: KSpace.xs),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!c.isLocalOnly) KConsultationStatusPill(status: c.status, dense: true),
                          KUrgencyPill(level: c.urgency, prefix: 'Urgence', dense: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.md),
          ..._statusBanner(context),
          if (hidden)
            KBanner(
              tone: KTone.info,
              icon: Icons.hourglass_top_rounded,
              message: c.effectiveSummary?.patientStatusLabel ??
                  'Votre consultation est en cours d’examen par un spécialiste. Le compte-rendu apparaîtra ici.',
            )
          else ...[
            if (c.images.isNotEmpty) OtoscopyPhotos(images: c.images),
            ClinicalFactsCard(consultation: c),
            if (c.hasAiResult) ...[
              const SizedBox(height: KSpace.md),
              AiProposalBlock(summary: c.summary),
            ],
            if (c.expertiseReview != null) ...[
              const SizedBox(height: KSpace.md),
              SpecialistOpinionBlock(consultation: c),
            ],
            if (!widget.forPatient && widget.onRequestExpertise != null && c.canRequestExpertise)
              ExpertiseRequestPanel(
                consultation: c,
                onRequest: widget.onRequestExpertise!,
                onUpdated: _updated,
              ),
            if (c.hasAiResult && !widget.forPatient) ...[
              const SizedBox(height: KSpace.md),
              Text(
                'La proposition de l’IA aide à décider. Elle ne remplace pas votre examen.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: k.inkMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _statusBanner(BuildContext context) {
    final c = _case;
    Widget? banner;
    if (c.upload == LocalUpload.pending) {
      banner = const KBanner(
        tone: KTone.info,
        icon: Icons.cloud_upload_outlined,
        title: 'Pas encore envoyée',
        message: 'La consultation est enregistrée sur ce téléphone. Elle partira automatiquement dès que le '
            'réseau revient, puis l’analyse IA démarrera.',
      );
    } else if (c.upload == LocalUpload.failed) {
      banner = KBanner(
        tone: KTone.danger,
        icon: Icons.cloud_off_outlined,
        title: 'Envoi refusé par le serveur',
        message: c.aiErrorMessage ?? 'Le serveur a refusé cette consultation. Voir les éléments en échec.',
      );
    } else if (c.isAiFailed && !widget.forPatient) {
      banner = KCard(
        borderColor: context.k.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: context.k.warning),
                const SizedBox(width: KSpace.xs),
                Expanded(child: Text('L’analyse IA n’a pas abouti', style: context.text.titleSmall)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${c.aiErrorDisplay} La consultation est bien enregistrée.',
              style: context.text.bodyMedium?.copyWith(color: context.k.inkMuted),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: KSpace.sm),
              KAsyncButton(
                label: 'Relancer l’analyse',
                busyLabel: 'Analyse en cours…',
                icon: Icons.refresh_rounded,
                onPressed: _retry,
              ),
            ],
          ],
        ),
      );
    } else if (c.isDraft && !widget.forPatient) {
      banner = KBanner(
        tone: KTone.warning,
        icon: Icons.edit_note_rounded,
        title: 'Brouillon',
        message: 'Cette consultation n’a pas été envoyée pour analyse.',
        actionLabel: widget.onResumeDraft == null ? null : 'Reprendre',
        onAction: widget.onResumeDraft == null ? null : () => widget.onResumeDraft!(c),
      );
    } else if (c.status == ConsultationStatus.pendingAi.value) {
      banner = const KBanner(
        tone: KTone.info,
        icon: Icons.hourglass_top_rounded,
        title: 'Analyse en attente',
        message: 'L’analyse démarrera dès que le serveur sera joignable. Le résultat apparaîtra ici.',
      );
    }
    return banner == null ? const [] : [banner, const SizedBox(height: KSpace.md)];
  }
}
