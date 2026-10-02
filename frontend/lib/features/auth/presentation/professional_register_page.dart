import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import '../../../core/facilities/facility_field.dart';

/// Inscription des professionnels de santé : infirmier·ère (validation par
/// l'encadrant) ou spécialiste (vérifié par matricule, connexion immédiate).
class ProfessionalRegisterPage extends StatefulWidget {
  const ProfessionalRegisterPage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<ProfessionalRegisterPage> createState() => _ProfessionalRegisterPageState();
}

enum _Role { nurse, specialist }

class _ProfessionalRegisterPageState extends State<ProfessionalRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  _Role _role = _Role.nurse;
  bool _obscure = true;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _healthFacility = TextEditingController();
  final _professionalId = TextEditingController();
  final _matricule = TextEditingController();
  final _supervisorMatricule = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _email,
      _password,
      _phone,
      _healthFacility,
      _professionalId,
      _matricule,
      _supervisorMatricule,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    widget.session.clearError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_role == _Role.nurse) {
      final message = await widget.session.registerNurse(
        fullName: _fullName.text,
        email: _email.text,
        password: _password.text,
        healthFacility: _healthFacility.text,
        supervisorMatricule: _supervisorMatricule.text,
        phone: _phone.text,
        professionalId: _professionalId.text,
      );
      if (!mounted || message == null) return;
      final matricule = _supervisorMatricule.text.trim().toUpperCase();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => KResultScreen(
            kind: KResultKind.success,
            title: 'Demande envoyée',
            message: 'Votre compte sera activé dès que votre encadrant aura validé votre inscription.',
            details: KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prochaine étape', style: ctx.text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'L’encadrant de matricule $matricule reçoit votre demande dans son espace. '
                    'Vous pourrez vous connecter avec ${_email.text.trim()} après sa validation.',
                    style: ctx.text.bodyMedium?.copyWith(color: ctx.k.inkMuted),
                  ),
                ],
              ),
            ),
            primaryLabel: 'Retour à la connexion',
            onPrimary: () => Navigator.of(ctx).popUntil((r) => r.isFirst),
          ),
        ),
      );
    } else {
      final message = await widget.session.registerSpecialist(
        fullName: _fullName.text,
        email: _email.text,
        password: _password.text,
        matricule: _matricule.text,
        phone: _phone.text,
        healthFacility: _healthFacility.text,
      );
      if (!mounted || message == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => KResultScreen(
            kind: KResultKind.success,
            title: 'Demande envoyée',
            message: 'Votre compte spécialiste sera activé après vérification de votre identité par un administrateur.',
            details: KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prochaine étape', style: ctx.text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Un administrateur Korai vérifie votre matricule et votre identité. '
                    'Vous pourrez ensuite vous connecter avec ${_email.text.trim()}.',
                    style: ctx.text.bodyMedium?.copyWith(color: ctx.k.inkMuted),
                  ),
                ],
              ),
            ),
            primaryLabel: 'Retour à la connexion',
            onPrimary: () => Navigator.of(ctx).popUntil((r) => r.isFirst),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      bloc: widget.session,
      builder: (context, state) {
        final isNurse = _role == _Role.nurse;
        final busy = state.isSubmitting;
        return Scaffold(
          appBar: AppBar(title: const Text('Inscription professionnelle')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KSegmented<_Role>(
                      segments: const [
                        KSegment(value: _Role.nurse, label: 'Infirmier·ère'),
                        KSegment(value: _Role.specialist, label: 'Spécialiste ORL'),
                      ],
                      value: _role,
                      onChanged: busy
                          ? (_) {}
                          : (r) {
                              widget.session.clearError();
                              setState(() => _role = r);
                            },
                    ),
                    const SizedBox(height: KSpace.md),
                    KBanner(
                      tone: KTone.info,
                      message: isNurse
                          ? 'Votre compte sera activé après validation par votre encadrant ORL, identifié par son matricule.'
                          : 'Votre matricule est vérifié dans le registre des médecins : votre compte est actif immédiatement.',
                    ),
                    const SizedBox(height: KSpace.lg),
                    _field(_fullName, 'Nom complet', Icons.person_outline_rounded,
                        validator: (v) => KValidators.minLength(v, 'Nom complet', 2),
                        caps: TextCapitalization.words,
                        hints: const [AutofillHints.name]),
                    _field(_email, 'Adresse e-mail', Icons.mail_outline_rounded,
                        keyboard: TextInputType.emailAddress,
                        validator: KValidators.email,
                        hints: const [AutofillHints.email]),
                    _passwordField(),
                    _field(_phone, 'Téléphone (facultatif)', Icons.phone_outlined,
                        keyboard: TextInputType.phone, validator: KValidators.phoneOptional),
                    if (isNurse) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: KSpace.sm),
                        child: FacilityField(
                          controller: _healthFacility,
                          apiClient: widget.session.apiClient,
                          label: 'Établissement de santé',
                          helperText:
                              'Choisissez-le dans la liste s’il y figure : vous verrez les dossiers de vos collègues.',
                          validator: (v) => KValidators.minLength(v, 'Établissement de santé', 2),
                        ),
                      ),
                      _field(_professionalId, 'Identifiant professionnel (facultatif)', Icons.badge_outlined),
                      _field(_supervisorMatricule, 'Matricule de votre encadrant', Icons.key_outlined,
                          helper: 'Demandez-le à votre encadrant ORL (exemple : ORL001).',
                          caps: TextCapitalization.characters,
                          validator: (v) => KValidators.required(v, 'Matricule de l’encadrant')),
                    ] else ...[
                      _field(_matricule, 'Votre matricule', Icons.key_outlined,
                          helper: 'Tel qu’inscrit au registre des médecins (exemple : ORL001).',
                          caps: TextCapitalization.characters,
                          validator: (v) => KValidators.required(v, 'Matricule')),
                      _field(_healthFacility, 'Structure de santé (facultatif)', Icons.local_hospital_outlined,
                          validator: (v) => KValidators.optionalMinLength(v, 'Structure de santé', 2)),
                    ],
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: KSpace.xs),
                      KBanner(title: 'Inscription impossible', message: state.errorMessage!, tone: KTone.danger),
                    ],
                    const SizedBox(height: KSpace.lg),
                    KAsyncButton(
                      label: isNurse ? 'Envoyer ma demande' : 'Créer mon compte spécialiste',
                      busyLabel: isNurse ? 'Envoi de la demande…' : 'Vérification du matricule…',
                      icon: Icons.send_rounded,
                      onPressed: busy ? null : _submit,
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

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: TextFormField(
        controller: _password,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'Mot de passe',
          helperText: '8 caractères minimum.',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: KValidators.password,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    String? helper,
    TextCapitalization caps = TextCapitalization.none,
    List<String>? hints,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        textCapitalization: caps,
        textInputAction: TextInputAction.next,
        autofillHints: hints,
        decoration: InputDecoration(labelText: label, helperText: helper, prefixIcon: Icon(icon)),
        validator: validator,
      ),
    );
  }
}
