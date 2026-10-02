import 'package:flutter/material.dart';

import '../design/design.dart';

/// Accords du patient : analyse par l'IA et avis d'un spécialiste. Décochés
/// tant que le patient ne les a pas donnés ; le serveur les vérifie avant tout
/// envoi de ses données.
class ConsentFields extends StatelessWidget {
  const ConsentFields({
    super.key,
    required this.ai,
    required this.teleExpertise,
    required this.onChanged,
    this.forPatient = false,
    this.enabled = true,
  });

  final bool ai;
  final bool teleExpertise;
  final void Function({required bool ai, required bool teleExpertise}) onChanged;

  /// Libellés adressés au patient lui-même (inscription, profil).
  final bool forPatient;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return KCard(
      padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.xs, KSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(forPatient ? 'Vos accords' : 'Accords du patient', style: context.text.titleSmall),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(right: KSpace.sm),
            child: Text(
              forPatient
                  ? 'Vous pouvez les modifier à tout moment dans votre profil.'
                  : 'Expliquez-les au patient et cochez seulement ce qu’il accepte.',
              style: context.text.bodySmall?.copyWith(color: k.inkMuted),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: ai,
            onChanged: enabled ? (v) => onChanged(ai: v, teleExpertise: teleExpertise) : null,
            title: const Text('Analyse par l’IA'),
            subtitle: Text(
              forPatient
                  ? 'Vos symptômes, sans votre nom ni votre téléphone, sont analysés par l’IA de Korai. '
                      'Obligatoire pour une consultation dans Korai.'
                  : 'Les données cliniques, sans nom ni téléphone, sont analysées par l’IA de Korai. '
                      'Obligatoire pour enregistrer une consultation.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: teleExpertise,
            onChanged: enabled ? (v) => onChanged(ai: ai, teleExpertise: v) : null,
            title: const Text('Avis d’un spécialiste'),
            subtitle: Text(
              forPatient
                  ? 'Votre dossier peut être partagé avec un médecin ORL de Korai.'
                  : 'Le dossier peut être partagé avec un médecin ORL de Korai (télé-expertise).',
            ),
          ),
        ],
      ),
    );
  }
}

/// Résumé des accords (dossier, listes d'administration).
class ConsentPills extends StatelessWidget {
  const ConsentPills({super.key, required this.ai, required this.teleExpertise});

  final bool ai;
  final bool teleExpertise;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        KPill(
          label: ai ? 'IA acceptée' : 'Sans accord pour l’IA',
          icon: ai ? Icons.check_rounded : Icons.block_rounded,
          tone: ai ? KTone.success : KTone.danger,
          dense: true,
        ),
        KPill(
          label: teleExpertise ? 'Télé-expertise acceptée' : 'Sans accord de télé-expertise',
          icon: teleExpertise ? Icons.check_rounded : Icons.block_rounded,
          tone: teleExpertise ? KTone.success : KTone.neutral,
          dense: true,
        ),
      ],
    );
  }
}

/// Feuille « Modifier les accords » : [onSave] enregistre (réseau requis) ;
/// renvoie `true` si les accords ont été enregistrés.
Future<bool> showConsentSheet(
  BuildContext context, {
  required String patientName,
  required bool ai,
  required bool teleExpertise,
  required Future<void> Function({required bool ai, required bool teleExpertise}) onSave,
  bool forPatient = false,
}) async {
  var currentAi = ai;
  var currentTele = teleExpertise;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(forPatient ? 'Mes accords' : 'Accords de $patientName', style: sheetContext.text.titleLarge),
              const SizedBox(height: KSpace.sm),
              ConsentFields(
                ai: currentAi,
                teleExpertise: currentTele,
                forPatient: forPatient,
                onChanged: ({required ai, required teleExpertise}) => setState(() {
                  currentAi = ai;
                  currentTele = teleExpertise;
                }),
              ),
              const SizedBox(height: KSpace.md),
              KAsyncButton(
                label: 'Enregistrer',
                icon: Icons.check_rounded,
                busyLabel: 'Enregistrement…',
                onPressed: () async {
                  try {
                    await onSave(ai: currentAi, teleExpertise: currentTele);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop(true);
                  } catch (error) {
                    if (sheetContext.mounted) KSnack.error(sheetContext, error);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return saved ?? false;
}
