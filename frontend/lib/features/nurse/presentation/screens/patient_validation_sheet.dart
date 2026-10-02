import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/utils/patient_age.dart';
import '../../domain/patient.dart';
import '../nurse_consultation_view_model.dart';
import '../nurse_workspace.dart';

/// Fiche d'un compte patient créé par le patient lui-même : le soignant
/// vérifie l'identité et la pré-consultation, puis valide.
Future<void> showPatientValidationSheet(
  BuildContext context, {
  required NurseWorkspace workspace,
  required NurseConsultationViewModel viewModel,
  required Patient patient,
  required void Function(Patient validated, String? narrative) onValidated,
}) {
  final preCase = viewModel.findPatientPreconsultationCase(workspace.cases, patient.id);
  final narrative = preCase?.symptoms;
  final preview = viewModel.buildPreconsultationPreview(narrative);

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.xl),
        children: [
          Row(
            children: [
              KInitialsAvatar(name: patient.fullName, size: 52),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.fullName, style: context.text.headlineSmall),
                    const KPill(label: 'Compte à valider', icon: Icons.fact_check_outlined, tone: KTone.warning, dense: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.md),
          Text(
            'Le patient a créé son compte depuis l’application. Vérifiez son identité avec lui avant de valider : il ne pourra plus modifier ces informations ensuite.',
            style: context.text.bodyMedium?.copyWith(color: context.k.inkMuted),
          ),
          const SizedBox(height: KSpace.md),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Identité', style: context.text.titleMedium),
                KInfoRow(label: 'Téléphone', value: patient.phone ?? 'Non renseigné'),
                KInfoRow(label: 'Adresse', value: patient.address ?? 'Non renseignée'),
                KInfoRow(label: 'Âge', value: PatientAge.label(patient.birthDate)),
                KInfoRow(label: 'Sexe', value: KLabels.sex(patient.sex)),
              ],
            ),
          ),
          const SizedBox(height: KSpace.sm),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Déclaré par le patient', style: context.text.titleMedium),
                const SizedBox(height: KSpace.xs),
                if (!preview.hasClinicalData)
                  Text('Le patient n’a pas encore décrit ses symptômes.', style: context.text.bodyMedium?.copyWith(color: context.k.inkMuted))
                else ...[
                  _Chips(title: 'Symptômes', labels: preview.symptomLabels),
                  _Chips(title: 'Antécédents', labels: preview.historyLabels),
                  if (preview.touchCheckLabels.isNotEmpty) _Chips(title: 'Au toucher', labels: preview.touchCheckLabels),
                  if (preview.notes?.isNotEmpty ?? false) KInfoRow(label: 'Notes', value: preview.notes!),
                ],
              ],
            ),
          ),
          const SizedBox(height: KSpace.lg),
          KAsyncButton(
            label: 'Valider et commencer la consultation',
            busyLabel: 'Validation du compte…',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () async {
              try {
                final validated = await workspace.validatePatient(patient);
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                KSnack.success(sheetContext, 'Compte de ${validated.fullName} validé.');
                onValidated(validated, narrative);
              } catch (e) {
                if (sheetContext.mounted) KSnack.error(sheetContext, e);
              }
            },
          ),
          const SizedBox(height: KSpace.xs),
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Plus tard')),
          ),
        ],
      ),
    ),
  );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.title, required this.labels});

  final String title;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.labelMedium?.copyWith(color: context.k.inkMuted)),
          const SizedBox(height: 6),
          if (labels.isEmpty)
            Text('Aucun', style: context.text.bodyMedium)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final l in labels) KPill(label: l, tone: KTone.brand, dense: true)],
            ),
        ],
      ),
    );
  }
}
