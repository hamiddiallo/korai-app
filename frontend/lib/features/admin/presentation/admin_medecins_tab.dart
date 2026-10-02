import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'admin_widgets.dart';

/// Registre des médecins : matricules de référence vérifiés à l'inscription
/// des spécialistes et des infirmier·ères encadré·es.
class MedecinsTab extends StatefulWidget {
  const MedecinsTab({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<MedecinsTab> createState() => _MedecinsTabState();
}

class _MedecinsTabState extends State<MedecinsTab> {
  List<Medecin> _items = const [];
  bool _loading = true;
  bool _loadedOnce = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repository.listMedecins();
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
        _loadedOnce = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Medecin? medecin]) async {
    final isNew = medecin == null;
    final matricule = TextEditingController(text: medecin?.matricule);
    final prenom = TextEditingController(text: medecin?.prenom);
    final nom = TextEditingController(text: medecin?.nom);

    final saved = await showAdminFormSheet(
      context,
      title: isNew ? 'Nouveau médecin' : 'Modifier le médecin',
      submitLabel: isNew ? 'Ajouter au registre' : 'Enregistrer',
      fields: (context, setState) => [
        TextFormField(
          controller: matricule,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Matricule', prefixIcon: Icon(Icons.key_outlined)),
          validator: (v) => KValidators.required(v, 'Matricule'),
        ),
        const SizedBox(height: KSpace.sm),
        TextFormField(
          controller: prenom,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person_outline_rounded)),
          validator: (v) => KValidators.required(v, 'Prénom'),
        ),
        const SizedBox(height: KSpace.sm),
        TextFormField(
          controller: nom,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.badge_outlined)),
          validator: (v) => KValidators.required(v, 'Nom'),
        ),
      ],
      controllers: [matricule, prenom, nom],
      onSubmit: () async {
        final data = {
          'matricule': matricule.text.trim(),
          'prenom': prenom.text.trim(),
          'nom': nom.text.trim(),
        };
        if (isNew) {
          await widget.repository.createMedecin(data);
        } else {
          await widget.repository.updateMedecin(medecin.id, data);
        }
      },
    );
    final name = '${prenom.text.trim()} ${nom.text.trim()}';
    if (!saved || !mounted) return;
    KSnack.success(context, isNew ? '$name ajouté au registre.' : 'Modifications enregistrées.');
    _load();
  }

  Future<void> _delete(Medecin m) async {
    final ok = await confirmDelete(
      context,
      title: 'Retirer du registre ?',
      message: '${m.prenom} ${m.nom} (${m.matricule}) ne pourra plus servir de référence à une inscription.',
    );
    if (!ok || !mounted) return;
    try {
      await widget.repository.deleteMedecin(m.id);
      if (!mounted) return;
      KSnack.success(context, '${m.prenom} ${m.nom} retiré du registre.');
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
      emptyIcon: Icons.badge_outlined,
      emptyTitle: 'Registre vide',
      emptyMessage: 'Ajoutez les matricules des médecins autorisés à s’inscrire ou à encadrer.',
      children: [
        for (final m in _items)
          AdminRow(
            leading: KInitialsAvatar(name: '${m.prenom} ${m.nom}', size: 40),
            title: '${m.prenom} ${m.nom}',
            subtitle: 'Matricule ${m.matricule}',
            onEdit: () => _openForm(m),
            onDelete: () => _delete(m),
            deleteTooltip: 'Retirer du registre',
          ),
      ],
    );
  }
}
