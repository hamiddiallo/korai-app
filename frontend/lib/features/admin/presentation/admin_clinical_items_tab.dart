import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'admin_widgets.dart';

/// Libellés d'un type de référentiel clinique, accordés en genre.
class ClinicalKind {
  const ClinicalKind({
    required this.type,
    required this.singular,
    required this.plural,
    required this.newTitle,
    required this.editTitle,
    required this.icon,
    required this.dangerHelp,
  });

  final String type;
  final String singular;
  final String plural;
  final String newTitle;
  final String editTitle;
  final IconData icon;

  /// Rôle du score de danger de ce type dans le calcul de l'urgence.
  final String dangerHelp;

  static const symptom = ClinicalKind(
    type: 'SYMPTOM',
    singular: 'symptôme',
    plural: 'symptômes',
    newTitle: 'Nouveau symptôme',
    editTitle: 'Modifier le symptôme',
    icon: Icons.sick_outlined,
    dangerHelp: 'Compte dans l’urgence dès que le symptôme est coché.',
  );
  static const history = ClinicalKind(
    type: 'MEDICAL_HISTORY',
    singular: 'antécédent',
    plural: 'antécédents',
    newTitle: 'Nouvel antécédent',
    editTitle: 'Modifier l’antécédent',
    icon: Icons.history_edu_outlined,
    dangerHelp: 'Aggrave un symptôme préoccupant. Seul, un antécédent ne dépasse pas l’urgence moyenne.',
  );
  static const touch = ClinicalKind(
    type: 'TOUCH_CHECK',
    singular: 'vérification au toucher',
    plural: 'vérifications au toucher',
    newTitle: 'Nouvelle vérification au toucher',
    editTitle: 'Modifier la vérification',
    icon: Icons.touch_app_outlined,
    dangerHelp: 'Compte dans l’urgence seulement si le résultat est anormal.',
  );
}

/// Référentiel clinique (symptômes, antécédents, examen au toucher) proposé
/// aux soignants et aux patients, et utilisé pour estimer l'urgence.
class ClinicalItemsTab extends StatefulWidget {
  const ClinicalItemsTab({super.key, required this.repository, required this.kind});

  final AdminRepository repository;
  final ClinicalKind kind;

  @override
  State<ClinicalItemsTab> createState() => _ClinicalItemsTabState();
}

class _ClinicalItemsTabState extends State<ClinicalItemsTab> {
  List<ClinicalReferenceItem> _items = const [];
  bool _loading = true;
  bool _loadedOnce = false;
  Object? _error;

  static const _dangerLabels = {
    0: '0 — Bénin',
    1: '1 — À surveiller',
    2: '2 — Préoccupant',
    3: '3 — Critique',
  };

  ClinicalKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await widget.repository.listClinicalItems(kind.type);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loadedOnce = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([ClinicalReferenceItem? item]) async {
    final isNew = item == null;
    final label = TextEditingController(text: item?.label);
    final description = TextEditingController(text: item?.description);
    var isActive = item?.isActive ?? true;
    var dangerScore = item?.dangerScore ?? 0;

    final saved = await showAdminFormSheet(
      context,
      title: isNew ? kind.newTitle : kind.editTitle,
      submitLabel: isNew ? 'Ajouter' : 'Enregistrer',
      fields: (context, setState) => [
        TextFormField(
          controller: label,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Libellé', prefixIcon: Icon(Icons.label_outline_rounded)),
          validator: (v) => KValidators.required(v, 'Libellé'),
        ),
        const SizedBox(height: KSpace.sm),
        TextFormField(
          controller: description,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Définition (facultatif)',
            helperText: 'Affichée par le bouton « i » pendant la consultation.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: KSpace.sm),
        DropdownButtonFormField<int>(
          initialValue: dangerScore,
          decoration: InputDecoration(
            labelText: 'Score de danger',
            helperText: kind.dangerHelp,
            helperMaxLines: 3,
            prefixIcon: const Icon(Icons.priority_high_rounded),
          ),
          items: [
            for (final e in _dangerLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => dangerScore = v ?? 0),
        ),
        const SizedBox(height: KSpace.xs),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Proposé en consultation'),
          subtitle: const Text('Visible par les soignants et les patients.'),
          value: isActive,
          onChanged: (v) => setState(() => isActive = v),
        ),
      ],
      controllers: [label, description],
      onSubmit: () async {
        final data = <String, dynamic>{
          'type': kind.type,
          'label': label.text.trim(),
          if (description.text.trim().isNotEmpty) 'description': description.text.trim(),
          'isActive': isActive,
          'dangerScore': dangerScore,
        };
        if (isNew) {
          await widget.repository.createClinicalItem(data);
        } else {
          await widget.repository.updateClinicalItem(item.id, data);
        }
      },
    );
    final name = label.text.trim();
    if (!saved || !mounted) return;
    KSnack.success(context, isNew ? '« $name » ajouté.' : 'Modifications enregistrées.');
    _load();
  }

  Future<void> _delete(ClinicalReferenceItem item) async {
    final ok = await confirmDelete(
      context,
      title: 'Supprimer « ${item.label} » ?',
      message: 'Il ne sera plus proposé en consultation. Pour le masquer sans le supprimer, désactivez-le plutôt.',
    );
    if (!ok || !mounted) return;
    try {
      await widget.repository.deleteClinicalItem(item.id);
      if (!mounted) return;
      KSnack.success(context, '« ${item.label} » supprimé.');
      _load();
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminListScaffold(
      loading: _loading,
      loadedOnce: _loadedOnce,
      error: _error,
      onRefresh: _load,
      createLabel: 'Ajouter',
      onCreate: () => _openForm(),
      emptyIcon: kind.icon,
      emptyTitle: 'Aucun ${kind.singular}',
      emptyMessage: 'Ajoutez les ${kind.plural} proposés pendant la consultation.',
      children: [
        for (final item in _items)
          AdminRow(
            leading: AdminLeadingIcon(
              icon: item.isActive ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
              tone: item.isActive ? KTone.success : KTone.neutral,
            ),
            title: item.label,
            subtitle: item.description?.trim().isNotEmpty ?? false ? item.description : 'Sans définition',
            footer: item.isActive ? null : const KPill(label: 'Masqué en consultation', dense: true),
            trailing: DangerScoreBadge(score: item.dangerScore),
            onEdit: () => _openForm(item),
            onDelete: () => _delete(item),
          ),
      ],
    );
  }
}
