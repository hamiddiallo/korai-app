import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/refresh/live_refresh.dart';
import '../../../core/utils/validators.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'admin_widgets.dart';

/// Comptes des professionnels, patients et administrateurs.
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> with LiveReloadState {
  List<AdminUser> _users = const [];
  bool _loading = true;
  bool _loadedOnce = false;
  Object? _error;
  String? _roleFilter;

  /// Filtre « À valider » : inscriptions en attente de vérification.
  bool _pendingOnly = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Relu au retour de l'application au premier plan (changements faits ailleurs).
  @override
  Future<void> liveReload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await widget.repository.listUsers();
      if (!mounted) return;
      setState(() {
        // Première ouverture : les inscriptions à vérifier d'abord.
        if (!_loadedOnce && users.any((u) => u.isPending)) _pendingOnly = true;
        if (_pendingOnly && !users.any((u) => u.isPending)) _pendingOnly = false;
        _users = users;
        _error = null;
        _loadedOnce = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([AdminUser? user]) async {
    final isNew = user == null;
    final fullName = TextEditingController(text: user?.fullName);
    final email = TextEditingController(text: user?.email);
    final password = TextEditingController();
    final phone = TextEditingController(text: user?.phone);
    final facility = TextEditingController(text: user?.healthFacility);
    final professionalId = TextEditingController(text: user?.professionalId);
    var role = user?.role ?? 'NURSE';

    final saved = await showAdminFormSheet(
      context,
      title: isNew ? 'Nouveau compte' : 'Modifier le compte',
      submitLabel: isNew ? 'Créer le compte' : 'Enregistrer',
      fields: (context, setState) => [
        TextFormField(
          controller: fullName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline_rounded)),
          validator: (v) => KValidators.minLength(v, 'Nom complet', 2),
        ),
        const SizedBox(height: KSpace.sm),
        TextFormField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Adresse e-mail', prefixIcon: Icon(Icons.mail_outline_rounded)),
          validator: KValidators.email,
        ),
        if (isNew) ...[
          const SizedBox(height: KSpace.sm),
          TextFormField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mot de passe provisoire',
              helperText: '8 caractères minimum. À transmettre à la personne.',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: KValidators.password,
          ),
        ],
        const SizedBox(height: KSpace.sm),
        DropdownButtonFormField<String>(
          initialValue: role,
          decoration: const InputDecoration(labelText: 'Rôle', prefixIcon: Icon(Icons.badge_outlined)),
          items: [
            for (final r in const ['NURSE', 'SPECIALIST', 'PATIENT', 'ADMIN'])
              DropdownMenuItem(value: r, child: Text(KLabels.role(r))),
          ],
          onChanged: (v) => setState(() => role = v ?? role),
        ),
        const SizedBox(height: KSpace.sm),
        TextFormField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration:
              const InputDecoration(labelText: 'Téléphone (facultatif)', prefixIcon: Icon(Icons.phone_outlined)),
          validator: KValidators.phoneOptional,
        ),
        const SizedBox(height: KSpace.sm),
        TextFormField(
          controller: facility,
          decoration: const InputDecoration(
            labelText: 'Structure de santé (facultatif)',
            prefixIcon: Icon(Icons.local_hospital_outlined),
          ),
        ),
        const SizedBox(height: KSpace.sm),
        TextFormField(
          controller: professionalId,
          decoration: const InputDecoration(
            labelText: 'Identifiant professionnel (facultatif)',
            prefixIcon: Icon(Icons.assignment_ind_outlined),
          ),
        ),
      ],
      controllers: [fullName, email, password, phone, facility, professionalId],
      onSubmit: () async {
        final data = <String, dynamic>{
          'fullName': fullName.text.trim(),
          'email': email.text.trim(),
          'role': role,
          if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
          if (facility.text.trim().isNotEmpty) 'healthFacility': facility.text.trim(),
          if (professionalId.text.trim().isNotEmpty) 'professionalId': professionalId.text.trim(),
          if (isNew) 'password': password.text,
        };
        if (isNew) {
          await widget.repository.createUser(data);
        } else {
          await widget.repository.updateUser(user.id, data);
        }
      },
    );
    final name = fullName.text.trim();
    if (!saved || !mounted) return;
    KSnack.success(context, isNew ? 'Compte de $name créé.' : 'Modifications enregistrées.');
    _load();
  }

  Future<void> _approve(AdminUser user) async {
    final ok = await showKConfirm(
      context,
      title: 'Activer ce compte ?',
      message: [
        'Vérifiez l’identité de ${user.fullName}',
        if (user.matricule != null) ' et son matricule ${user.matricule}',
        ' avant d’activer : ${KLabels.role(user.role).toLowerCase()}, il ou elle accédera aux dossiers qui lui sont confiés.',
      ].join(),
      confirmLabel: 'Activer',
    );
    if (!ok || !mounted) return;
    await _act(user, () => widget.repository.approveUser(user.id), 'Compte de ${user.fullName} activé.');
  }

  Future<void> _reject(AdminUser user) async {
    final reason = await showKReasonDialog(
      context,
      title: 'Refuser cette inscription ?',
      message: '${user.fullName} verra ce motif lors de sa prochaine tentative de connexion.',
    );
    if (reason == null || !mounted) return;
    await _act(
        user, () => widget.repository.rejectUser(user.id, reason: reason), 'Inscription de ${user.fullName} refusée.');
  }

  Future<void> _act(AdminUser user, Future<void> Function() action, String success) async {
    setState(() => _busy.add(user.id));
    try {
      await action();
      if (!mounted) return;
      KSnack.success(context, success);
      await _load();
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  Future<void> _delete(AdminUser user) async {
    final ok = await confirmDelete(
      context,
      title: 'Supprimer ce compte ?',
      message: '${user.fullName} ne pourra plus se connecter. Cette action est définitive.',
    );
    if (!ok || !mounted) return;
    try {
      await widget.repository.deleteUser(user.id);
      if (!mounted) return;
      KSnack.success(context, 'Compte de ${user.fullName} supprimé.');
      _load();
    } catch (e) {
      if (mounted) KSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = const ['NURSE', 'SPECIALIST', 'PATIENT', 'ADMIN'];
    final pending = _users.where((u) => u.isPending).toList();
    final shown =
        _pendingOnly ? pending : (_roleFilter == null ? _users : _users.where((u) => u.role == _roleFilter).toList());
    return AdminListScaffold(
      loading: _loading,
      loadedOnce: _loadedOnce,
      error: _error,
      onRefresh: _load,
      createLabel: 'Nouveau compte',
      onCreate: () => _openForm(),
      emptyIcon: Icons.group_outlined,
      emptyTitle: _pendingOnly
          ? 'Aucune inscription à valider'
          : (_roleFilter == null ? 'Aucun compte' : 'Aucun compte pour ce rôle'),
      emptyMessage: 'Créez un compte pour donner accès à Korai.',
      header: _loadedOnce
          ? SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xs),
                children: [
                  if (pending.isNotEmpty) ...[
                    ChoiceChip(
                      avatar: const Icon(Icons.hourglass_top_rounded, size: 18),
                      label: Text('À valider · ${pending.length}'),
                      selected: _pendingOnly,
                      onSelected: (_) => setState(() => _pendingOnly = true),
                    ),
                    const SizedBox(width: KSpace.xs),
                  ],
                  ChoiceChip(
                    label: Text('Tous · ${_users.length}'),
                    selected: !_pendingOnly && _roleFilter == null,
                    onSelected: (_) => setState(() {
                      _pendingOnly = false;
                      _roleFilter = null;
                    }),
                  ),
                  for (final r in roles) ...[
                    const SizedBox(width: KSpace.xs),
                    ChoiceChip(
                      label: Text('${KLabels.role(r)} · ${_users.where((u) => u.role == r).length}'),
                      selected: !_pendingOnly && _roleFilter == r,
                      onSelected: (_) => setState(() {
                        _pendingOnly = false;
                        _roleFilter = r;
                      }),
                    ),
                  ],
                ],
              ),
            )
          : null,
      children: [
        for (final u in shown)
          AdminRow(
            leading: KInitialsAvatar(name: u.fullName, size: 40),
            title: u.fullName,
            subtitle: [u.email, if (u.matricule != null) 'Matricule ${u.matricule}'].join(' · '),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    KPill(
                        label: KLabels.role(u.role), icon: Icons.badge_outlined, tone: _roleTone(u.role), dense: true),
                    if (u.isPending)
                      const KPill(
                          label: 'À valider', icon: Icons.hourglass_top_rounded, tone: KTone.warning, dense: true),
                    if (u.accountStatus == 'REJECTED')
                      const KPill(label: 'Refusé', icon: Icons.block_rounded, tone: KTone.danger, dense: true),
                  ],
                ),
                if (u.isPending) ...[
                  const SizedBox(height: KSpace.xs),
                  _busy.contains(u.id)
                      ? const LinearProgressIndicator(minHeight: 2)
                      : Wrap(
                          spacing: KSpace.xs,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _approve(u),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Activer'),
                            ),
                            OutlinedButton(onPressed: () => _reject(u), child: const Text('Refuser')),
                          ],
                        ),
                ],
              ],
            ),
            onEdit: u.isPending ? null : () => _openForm(u),
            onDelete: () => _delete(u),
          ),
      ],
    );
  }

  static KTone _roleTone(String role) => switch (role) {
        'ADMIN' => KTone.neutral,
        'SPECIALIST' => KTone.info,
        'NURSE' => KTone.brand,
        'PATIENT' => KTone.warning,
        _ => KTone.neutral,
      };
}
