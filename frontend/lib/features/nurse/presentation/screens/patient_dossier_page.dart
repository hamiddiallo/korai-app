import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/korai_enums.dart';
import '../../../../core/utils/consultation_format.dart';
import '../../../../core/utils/diagnosis_text.dart';
import '../../../../core/utils/patient_age.dart';
import '../../../../core/widgets/consent_fields.dart';
import '../../domain/ai_case.dart';
import '../../domain/patient.dart';
import '../nurse_actions.dart';
import '../nurse_workspace.dart';
import '../widgets/consultation_card.dart';

/// Dossier d'un patient : identité, chiffres clés, consultations, et
/// « Nouvelle consultation » toujours sous le pouce.
class PatientDossierPage extends StatelessWidget {
  const PatientDossierPage({super.key, required this.workspace, required this.patient, required this.actions});

  final NurseWorkspace workspace;
  final Patient patient;
  final NurseActions actions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: workspace,
      builder: (context, _) {
        final p = workspace.patientById(patient.id) ?? patient;
        final cases = workspace.casesFor(p.id);
        final draft = cases.where((c) => c.isDraft).firstOrNull;
        final k = context.k;
        final meta = [
          PatientAge.label(p.birthDate),
          if (KLabels.sexOrNull(p.sex) != null) KLabels.sexOrNull(p.sex)!,
          if (p.phone != null && p.phone!.trim().isNotEmpty) p.phone!,
        ].join(' · ');

        return Scaffold(
          appBar: AppBar(title: const Text('Dossier patient')),
          body: RefreshIndicator(
            onRefresh: workspace.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xl),
              children: [
                Row(
                  children: [
                    KInitialsAvatar(name: p.fullName, size: 64, heroTag: 'patient-${p.id}'),
                    const SizedBox(width: KSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.fullName, style: context.text.headlineSmall),
                          const SizedBox(height: 2),
                          Text(meta, style: context.text.bodyMedium?.copyWith(color: k.inkMuted)),
                          if (p.address != null && p.address!.trim().isNotEmpty)
                            Text(p.address!, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpace.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: ConsentPills(ai: p.consentForAi, teleExpertise: p.consentForTeleExpertise)),
                    TextButton(
                      onPressed: () async {
                        final saved = await showConsentSheet(
                          context,
                          patientName: p.fullName,
                          ai: p.consentForAi,
                          teleExpertise: p.consentForTeleExpertise,
                          onSave: ({required ai, required teleExpertise}) =>
                              workspace.updateConsents(p, ai: ai, teleExpertise: teleExpertise),
                        );
                        if (saved && context.mounted) KSnack.success(context, 'Accords enregistrés.');
                      },
                      child: const Text('Modifier'),
                    ),
                  ],
                ),
                const SizedBox(height: KSpace.md),
                if (!p.isValidated) ...[
                  KBanner(
                    tone: KTone.warning,
                    title: 'Compte à valider',
                    message: 'Le patient a créé son compte. Vérifiez son identité avant la consultation.',
                    actionLabel: 'Vérifier',
                    onAction: () => actions.reviewPendingPatient(p),
                  ),
                  const SizedBox(height: KSpace.md),
                ],
                _Stats(cases: cases),
                const SizedBox(height: KSpace.lg),
                KSectionHeader(title: 'Consultations', count: cases.isEmpty ? null : cases.length),
                const SizedBox(height: KSpace.xs),
                if (cases.isEmpty)
                  const KEmptyView(
                    icon: Icons.event_note_outlined,
                    title: 'Aucune consultation',
                    message: 'La première consultation de ce patient apparaîtra ici.',
                    compact: true,
                  )
                else
                  for (final c in cases) ...[
                    ConsultationCard(
                      consultation: c,
                      patientName: c.hasAiResult ? DiagnosisText.headline(c.displayDiagnosis) : 'Consultation ORL',
                      showDiagnosis: false,
                      onTap: () => actions.openConsultation(c),
                    ),
                    const SizedBox(height: KSpace.xs),
                  ],
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(color: k.surface, border: Border(top: BorderSide(color: k.line))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.gutter, KSpace.sm),
                child: Row(
                  children: [
                    if (draft != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => actions.startConsultation(patient: p, prefill: draft.symptoms),
                          child: const Text('Reprendre le brouillon'),
                        ),
                      ),
                      const SizedBox(width: KSpace.sm),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: p.isValidated
                            ? () => actions.startConsultation(patient: p)
                            : () => actions.reviewPendingPatient(p),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nouvelle consultation'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.cases});

  final List<AiCase> cases;

  @override
  Widget build(BuildContext context) {
    UrgencyLevel? maxUrgency;
    for (final c in cases) {
      if (maxUrgency == null || KUrgency.rank(c.urgency) < KUrgency.rank(maxUrgency)) maxUrgency = c.urgency;
    }
    return Row(
      children: [
        Expanded(child: _Stat(value: '${cases.length}', label: cases.length > 1 ? 'consultations' : 'consultation')),
        const SizedBox(width: KSpace.xs),
        Expanded(
          child: _Stat(
            value: cases.isEmpty
                ? '–'
                : ConsultationFormat.formatDate(cases.first.createdAt).replaceAll(RegExp(r' \d{4}$'), ''),
            label: 'dernière visite',
            small: true,
          ),
        ),
        const SizedBox(width: KSpace.xs),
        Expanded(
          child: _Stat(
            value: KUrgency.label(maxUrgency),
            label: 'urgence la plus haute',
            color: maxUrgency == null ? null : KUrgency.color(context, maxUrgency),
            small: true,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color, this.small = false});

  final String value;
  final String label;
  final Color? color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.all(KSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (small ? context.text.titleLarge : context.text.headlineMedium)?.copyWith(color: color),
          ),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );
  }
}
