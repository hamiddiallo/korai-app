import 'package:flutter/material.dart';

import '../design/design.dart';
import '../utils/validators.dart';
import 'session_controller.dart';

/// Feuille « Modifier mon profil » (nom, téléphone, structure, identifiant).
Future<void> showEditProfileSheet(BuildContext context, AuthCubit session, {bool showProfessionalFields = true}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditProfileSheet(session: session, showProfessionalFields: showProfessionalFields),
  );
}

/// Feuille « Changer le mot de passe ».
Future<void> showChangePasswordSheet(BuildContext context, AuthCubit session) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ChangePasswordSheet(session: session),
  );
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.text.headlineSmall),
              const SizedBox(height: KSpace.md),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.session, required this.showProfessionalFields});

  final AuthCubit session;
  final bool showProfessionalFields;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.session.user?.fullName);
  late final _phone = TextEditingController(text: widget.session.user?.phone);
  late final _facility = TextEditingController(text: widget.session.user?.healthFacility);
  late final _proId = TextEditingController(text: widget.session.user?.professionalId);
  String? _error;

  bool get _isNurse => widget.session.user?.role == 'NURSE';

  @override
  void dispose() {
    for (final c in [_name, _phone, _facility, _proId]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _error = null);
    try {
      await widget.session.updateProfile(
        fullName: _name.text,
        phone: _phone.text,
        healthFacility: _isNurse ? null : _facility.text,
        professionalId: _proId.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      KSnack.success(context, 'Profil mis à jour.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: _SheetScaffold(
        title: 'Modifier mon profil',
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: (v) => KValidators.minLength(v, 'Nom complet', 2),
          ),
          const SizedBox(height: KSpace.sm),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
            validator: KValidators.phoneOptional,
          ),
          if (widget.showProfessionalFields) ...[
            const SizedBox(height: KSpace.sm),
            // L'établissement d'un soignant détermine les dossiers qu'il voit :
            // seul un administrateur peut le changer.
            TextFormField(
              controller: _facility,
              readOnly: _isNurse,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Structure de santé',
                helperText: _isNurse ? 'Pour changer d’établissement, contactez un administrateur.' : null,
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.local_hospital_outlined),
                suffixIcon: _isNurse ? const Icon(Icons.lock_outline_rounded) : null,
              ),
              validator: (v) => KValidators.optionalMinLength(v, 'Structure de santé', 2),
            ),
            const SizedBox(height: KSpace.sm),
            TextFormField(
              controller: _proId,
              decoration:
                  const InputDecoration(labelText: 'Identifiant professionnel', prefixIcon: Icon(Icons.badge_outlined)),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: KSpace.md),
            KBanner(title: 'Enregistrement impossible', message: _error!, tone: KTone.danger),
          ],
          const SizedBox(height: KSpace.lg),
          KAsyncButton(label: 'Enregistrer', busyLabel: 'Enregistrement…', icon: Icons.check_rounded, onPressed: _save),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.session});

  final AuthCubit session;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_current, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _error = null);
    try {
      await widget.session.changePassword(currentPassword: _current.text, newPassword: _new.text);
      if (!mounted) return;
      Navigator.pop(context);
      KSnack.success(context, 'Mot de passe modifié.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      tooltip: _obscure ? 'Afficher les mots de passe' : 'Masquer les mots de passe',
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return Form(
      key: _formKey,
      child: _SheetScaffold(
        title: 'Changer le mot de passe',
        children: [
          TextFormField(
            controller: _current,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(labelText: 'Mot de passe actuel', suffixIcon: toggle),
            validator: (v) => KValidators.required(v, 'Mot de passe actuel'),
          ),
          const SizedBox(height: KSpace.sm),
          TextFormField(
            controller: _new,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Nouveau mot de passe', helperText: '8 caractères minimum.'),
            validator: KValidators.password,
          ),
          const SizedBox(height: KSpace.sm),
          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: 'Confirmer le nouveau mot de passe'),
            validator: (v) => v != _new.text ? 'Les deux mots de passe ne correspondent pas.' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: KSpace.md),
            KBanner(title: 'Modification impossible', message: _error!, tone: KTone.danger),
          ],
          const SizedBox(height: KSpace.lg),
          KAsyncButton(
              label: 'Changer le mot de passe',
              busyLabel: 'Enregistrement…',
              icon: Icons.lock_reset_rounded,
              onPressed: _save),
        ],
      ),
    );
  }
}
