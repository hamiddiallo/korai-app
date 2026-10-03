import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/korai_enums.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/clinical_reference_item.dart';

/// Question de l'étape en tête du contenu.
class StepQuestion extends StatelessWidget {
  const StepQuestion({super.key, required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: context.text.headlineSmall)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: context.text.bodyMedium?.copyWith(color: context.k.inkMuted)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Étape 1 : patient
// ---------------------------------------------------------------------------

class PatientInfoStep extends StatelessWidget {
  const PatientInfoStep({
    super.key,
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.phoneController,
    required this.addressController,
    required this.ageController,
    required this.sex,
    required this.onSexChanged,
    this.existingPatient = false,
    this.title,
    this.hint,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController ageController;
  final String sex;
  final ValueChanged<String> onSexChanged;
  final bool existingPatient;

  /// Remplacent la question par défaut (formulation côté patient, par ex.).
  final String? title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepQuestion(
            title: title ?? (existingPatient ? 'Vérifiez l’identité du patient' : 'Qui est le patient ?'),
            hint: hint ??
                (existingPatient
                    ? 'Dossier existant : corrigez si une information a changé.'
                    : 'Le dossier est créé sur l’appareil, même sans connexion.'),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: lastNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nom', hintText: 'Diallo'),
                  validator: (v) => KValidators.required(v, 'Nom'),
                ),
              ),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: TextFormField(
                  controller: firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Prénom', hintText: 'Aïssatou'),
                  validator: (v) => KValidators.required(v, 'Prénom'),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Âge', suffixText: 'ans'),
                  validator: (v) => KValidators.age(v, required: false),
                ),
              ),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: KSegmented<String>(
                  segments: const [
                    KSegment(value: 'F', label: 'Féminin'),
                    KSegment(value: 'M', label: 'Masculin'),
                  ],
                  value: sex,
                  onChanged: onSexChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.sm),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Téléphone (facultatif)',
              hintText: '77 123 45 67',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: KValidators.phoneOptional,
          ),
          const SizedBox(height: KSpace.sm),
          TextFormField(
            controller: addressController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Adresse (facultatif)',
              hintText: 'Quartier, ville',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Étapes 2 et 3 : puces sélectionnables (symptômes, antécédents)
// ---------------------------------------------------------------------------

class ClinicalChipsStep extends StatelessWidget {
  const ClinicalChipsStep({
    super.key,
    required this.title,
    required this.hint,
    required this.items,
    required this.selectedIds,
    required this.onChanged,
    required this.emptyText,
    required this.unitSingular,
    required this.unitPlural,
  });

  final String title;
  final String hint;
  final List<ClinicalReferenceItem> items;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onChanged;
  final String emptyText;
  final String unitSingular;
  final String unitPlural;

  @override
  Widget build(BuildContext context) {
    final n = selectedIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepQuestion(title: title, hint: hint),
        if (items.isEmpty)
          KEmptyView(icon: Icons.list_alt_rounded, title: emptyText, compact: true)
        else ...[
          Wrap(
            spacing: KSpace.xs,
            runSpacing: KSpace.xs,
            children: [
              for (final item in items)
                ClinicalChip(
                  label: item.label,
                  selected: selectedIds.contains(item.id),
                  onTap: () => onChanged(item.id, !selectedIds.contains(item.id)),
                  onInfo: item.description == null || item.description!.trim().isEmpty
                      ? null
                      : () => showDefinitionSheet(context, item.label, item.description!),
                ),
            ],
          ),
          const SizedBox(height: KSpace.md),
          Semantics(
            liveRegion: true,
            child: Text(
              n == 0
                  ? 'Aucun $unitSingular sélectionné'
                  : '$n ${n == 1 ? '$unitSingular sélectionné' : '$unitPlural sélectionnés'}',
              style: context.text.labelMedium?.copyWith(color: context.k.inkMuted),
            ),
          ),
        ],
      ],
    );
  }
}

/// Puce sélectionnable avec bouton « i » pour la définition.
class ClinicalChip extends StatelessWidget {
  const ClinicalChip({super.key, required this.label, required this.selected, required this.onTap, this.onInfo});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final fg = selected ? k.onBrand : k.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? k.brand : k.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? k.brand : k.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.only(left: 14, right: onInfo == null ? 14 : 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: KMotion.of(context, KMotion.fast),
                    child: selected
                        ? Padding(
                            key: const ValueKey('on'),
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.check_rounded, size: 18, color: fg),
                          )
                        : const SizedBox(key: ValueKey('off')),
                  ),
                  Flexible(
                    child: Text(
                      label,
                      style: context.text.labelLarge
                          ?.copyWith(color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
                  if (onInfo != null)
                    IconButton(
                      tooltip: 'Définition de « $label »',
                      onPressed: onInfo,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.info_outline_rounded, size: 19, color: selected ? k.onBrand : k.inkMuted),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showDefinitionSheet(BuildContext context, String title, String description) {
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ctx.text.headlineSmall),
            const SizedBox(height: KSpace.xs),
            Text(description, style: ctx.text.bodyLarge),
            const SizedBox(height: KSpace.lg),
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Étape 4 : examen au toucher
// ---------------------------------------------------------------------------

class TouchExamStep extends StatelessWidget {
  const TouchExamStep({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.observations,
    required this.options,
    required this.onSelectionChanged,
    required this.onObservationChanged,
  });

  final List<ClinicalReferenceItem> items;
  final Set<String> selectedIds;
  final Map<String, String> observations;

  /// Options du view-model ; la première (« Non réalisé ») = non cochée.
  final List<String> options;
  final void Function(String id, bool selected) onSelectionChanged;
  final void Function(String id, String value) onObservationChanged;

  static String shortLabel(String option) => switch (option) {
        'Non réalisé' => 'Non fait',
        'Normal (négatif)' => 'Normal',
        'Anormal — léger' => 'Léger',
        'Anormal — modéré' => 'Modéré',
        'Anormal — sévère' => 'Sévère',
        _ => option,
      };

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepQuestion(
          title: 'Qu’avez-vous observé à l’examen ?',
          hint: 'Pour chaque vérification réalisée, choisissez le résultat. Laissez « Non fait » sinon.',
        ),
        if (items.isEmpty)
          const KEmptyView(icon: Icons.touch_app_outlined, title: 'Aucune vérification configurée', compact: true)
        else
          for (final item in items) ...[
            KCard(
              borderColor: selectedIds.contains(item.id) ? k.brand : null,
              padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.xs, KSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.label, style: context.text.titleSmall)),
                      if (item.description != null && item.description!.trim().isNotEmpty)
                        IconButton(
                          tooltip: 'Définition de « ${item.label} »',
                          icon: Icon(Icons.info_outline_rounded, color: k.inkMuted, size: 20),
                          onPressed: () => showDefinitionSheet(context, item.label, item.description!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final option in options)
                        _ResultChip(
                          label: shortLabel(option),
                          selected: option == options.first
                              ? !selectedIds.contains(item.id)
                              : selectedIds.contains(item.id) && observations[item.id] == option,
                          tone: switch (option) {
                            'Anormal — sévère' => KTone.danger,
                            'Anormal — modéré' || 'Anormal — léger' => KTone.warning,
                            'Normal (négatif)' => KTone.success,
                            _ => KTone.neutral,
                          },
                          onTap: () {
                            if (option == options.first) {
                              onSelectionChanged(item.id, false);
                            } else {
                              if (!selectedIds.contains(item.id)) onSelectionChanged(item.id, true);
                              onObservationChanged(item.id, option);
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpace.xs),
          ],
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label, required this.selected, required this.tone, required this.onTap});

  final String label;
  final bool selected;
  final KTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final c = k.tone(tone);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.bg : k.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? c.accent : k.line, width: selected ? 1.6 : 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: context.text.labelMedium?.copyWith(
                    color: selected ? c.fg : k.inkMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Étape 6 : récapitulatif
// ---------------------------------------------------------------------------

class RecapStep extends StatelessWidget {
  const RecapStep({
    super.key,
    required this.patientName,
    required this.age,
    required this.sex,
    required this.phone,
    required this.earSide,
    required this.symptoms,
    required this.histories,
    required this.touchChecks,
    required this.photos,
    required this.urgency,
    required this.notesController,
    this.error,
    this.onRetry,
  });

  final String patientName;
  final String age;
  final String sex;
  final String phone;
  final EarSide earSide;
  final List<String> symptoms;
  final List<String> histories;
  final List<String> touchChecks;

  /// Photos à envoyer, par oreille (droite puis gauche).
  final Map<EarSide, File> photos;
  final UrgencyLevel urgency;
  final TextEditingController notesController;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final tone = k.tone(KUrgency.tone(urgency));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepQuestion(title: 'Vérifiez avant l’analyse', hint: 'Vous pouvez revenir à une étape pour corriger.'),
        if (error != null) ...[
          KBanner(
            tone: KTone.danger,
            title: 'L’analyse n’a pas pu être lancée',
            message: error!,
            actionLabel: onRetry == null ? null : 'Réessayer',
            onAction: onRetry,
          ),
          const SizedBox(height: KSpace.md),
        ],
        Container(
          padding: const EdgeInsets.all(KSpace.md),
          decoration: BoxDecoration(color: tone.bg, borderRadius: KRadius.cardAll),
          child: Row(
            children: [
              Icon(KUrgency.icon(urgency), color: tone.accent, size: 28),
              const SizedBox(width: KSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Urgence estimée : ${KUrgency.label(urgency).toLowerCase()}',
                        style: context.text.titleSmall?.copyWith(color: tone.fg)),
                    Text(
                      'Calculée à partir des symptômes, de l’examen au toucher et des antécédents. Le serveur la confirme à l’envoi.',
                      style: context.text.bodySmall?.copyWith(color: tone.fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.md),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient', style: context.text.titleMedium),
              KInfoRow(label: 'Nom', value: patientName.isEmpty ? 'Non renseigné' : patientName),
              KInfoRow(label: 'Âge', value: age.isEmpty ? 'Non renseigné' : '$age ans'),
              KInfoRow(label: 'Sexe', value: KLabels.sex(sex)),
              KInfoRow(label: 'Téléphone', value: phone.isEmpty ? 'Non renseigné' : phone),
              KInfoRow(label: 'Oreille', value: KLabels.earWithMark(earSide)),
            ],
          ),
        ),
        const SizedBox(height: KSpace.sm),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Examen', style: context.text.titleMedium),
              KInfoRow(label: 'Symptômes', value: symptoms.isEmpty ? 'Aucun' : symptoms.join(', ')),
              KInfoRow(label: 'Antécédents', value: histories.isEmpty ? 'Aucun' : histories.join(', ')),
              KInfoRow(label: 'Au toucher', value: touchChecks.isEmpty ? 'Non réalisé' : touchChecks.join('\n')),
              KInfoRow(
                label: photos.length > 1 ? 'Photos' : 'Photo',
                value: switch (photos.length) {
                  0 => 'Aucune : analyse des symptômes seule',
                  1 => 'Jointe (${KLabels.earShort(photos.keys.single)}) : analyse image + symptômes',
                  _ => 'Deux tympans : analyse de chaque image + symptômes',
                },
                valueColor: photos.isEmpty ? k.warningInk : k.successInk,
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: KSpace.xs),
                Row(
                  children: [
                    for (final MapEntry(key: side, value: photo) in photos.entries) ...[
                      if (side != photos.keys.first) const SizedBox(width: KSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: KRadius.controlAll,
                              child: Image.file(photo, height: 150, width: double.infinity, fit: BoxFit.cover),
                            ),
                            if (photos.length > 1) ...[
                              const SizedBox(height: 4),
                              Text(KLabels.earWithMark(side), style: context.text.labelMedium),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KSpace.md),
        TextFormField(
          controller: notesController,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes pour le dossier (facultatif)',
            hintText: 'Durée des symptômes, traitement déjà pris, contexte…',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Analyse en cours
// ---------------------------------------------------------------------------

/// Écran d'attente pendant l'analyse : les étapes réelles défilent, avec un
/// délai indicatif (l'analyse peut prendre jusqu'à deux minutes).
class AnalysisProgressView extends StatefulWidget {
  const AnalysisProgressView({super.key, required this.photoCount});

  /// Photos envoyées (0, 1, ou 2 pour les deux tympans).
  final int photoCount;

  @override
  State<AnalysisProgressView> createState() => _AnalysisProgressViewState();
}

class _AnalysisProgressViewState extends State<AnalysisProgressView> {
  late final List<String> _phases = [
    'Enregistrement sur l’appareil',
    if (widget.photoCount == 1) ...['Anonymisation de la photo', 'Analyse de l’image du tympan'],
    if (widget.photoCount > 1) ...['Anonymisation des photos', 'Analyse des images des deux tympans'],
    'Croisement avec les symptômes',
  ];
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (_current < _phases.length - 1) setState(() => _current++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Semantics(
      liveRegion: true,
      label: 'Analyse en cours : ${_phases[_current]}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Analyse en cours', style: context.text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Gardez l’application ouverte. L’analyse peut prendre jusqu’à deux minutes.',
              style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
            ),
            const SizedBox(height: KSpace.lg),
            for (var i = 0; i < _phases.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: i < _current
                          ? Icon(Icons.check_circle_rounded, color: k.success)
                          : i == _current
                              ? Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: CircularProgressIndicator(strokeWidth: 2.6, color: k.brand),
                                )
                              : Icon(Icons.radio_button_unchecked_rounded, color: k.line),
                    ),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      child: Text(
                        _phases[i],
                        style: context.text.bodyLarge?.copyWith(
                          color: i <= _current ? k.ink : k.inkMuted,
                          fontWeight: i == _current ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
