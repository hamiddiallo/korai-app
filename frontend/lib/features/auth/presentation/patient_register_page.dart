import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import '../../../core/facilities/facility_repository.dart';
import '../../../core/widgets/consent_fields.dart';

/// Création d'un compte patient. Connexion automatique en cas de succès.
class PatientRegisterPage extends StatefulWidget {
  const PatientRegisterPage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<PatientRegisterPage> createState() => _PatientRegisterPageState();
}

class _PatientRegisterPageState extends State<PatientRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _consentAi = false;
  bool _consentTele = false;
  String? _facilityId;
  late final Future<List<Facility>> _facilities =
      FacilityRepository(widget.session.apiClient).list().catchError((_) => <Facility>[]);

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    widget.session.clearError();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    await widget.session.registerPatient(
      firstName: _firstName.text,
      lastName: _lastName.text,
      email: _email.text,
      password: _password.text,
      phone: _phone.text,
      consentForAi: _consentAi,
      consentForTeleExpertise: _consentTele,
      facilityId: _facilityId,
    );
    if (!mounted) return;
    if (widget.session.isAuthenticated) {
      KSnack.success(context, 'Compte créé. Bienvenue sur Korai.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return BlocBuilder<AuthCubit, AuthState>(
      bloc: widget.session,
      builder: (context, state) {
        final busy = state.isSubmitting;
        return Scaffold(
          appBar: AppBar(title: const Text('Créer mon compte patient')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, KSpace.xl),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Votre compte vous permet de décrire vos symptômes avant la consultation et de retrouver l’avis du spécialiste.',
                        style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
                      ),
                      const SizedBox(height: KSpace.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstName,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.givenName],
                              decoration: const InputDecoration(labelText: 'Prénom'),
                              validator: (v) => KValidators.required(v, 'Prénom'),
                            ),
                          ),
                          const SizedBox(width: KSpace.sm),
                          Expanded(
                            child: TextFormField(
                              controller: _lastName,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.familyName],
                              decoration: const InputDecoration(labelText: 'Nom'),
                              validator: (v) => KValidators.required(v, 'Nom'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KSpace.sm),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Adresse e-mail',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: KValidators.email,
                      ),
                      const SizedBox(height: KSpace.sm),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'Téléphone (facultatif)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: KValidators.phoneOptional,
                      ),
                      const SizedBox(height: KSpace.sm),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
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
                      const SizedBox(height: KSpace.sm),
                      FutureBuilder<List<Facility>>(
                        future: _facilities,
                        builder: (context, snapshot) {
                          final facilities = snapshot.data ?? const <Facility>[];
                          if (facilities.isEmpty) return const SizedBox.shrink();
                          return DropdownButtonFormField<String?>(
                            initialValue: _facilityId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Où êtes-vous suivi ? (facultatif)',
                              helperText: 'Les soignants de cet établissement verront votre pré-consultation.',
                              helperMaxLines: 2,
                              prefixIcon: Icon(Icons.local_hospital_outlined),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Je ne sais pas encore')),
                              for (final f in facilities) DropdownMenuItem<String?>(value: f.id, child: Text(f.name)),
                            ],
                            onChanged: (v) => setState(() => _facilityId = v),
                          );
                        },
                      ),
                      const SizedBox(height: KSpace.md),
                      ConsentFields(
                        ai: _consentAi,
                        teleExpertise: _consentTele,
                        forPatient: true,
                        onChanged: ({required ai, required teleExpertise}) => setState(() {
                          _consentAi = ai;
                          _consentTele = teleExpertise;
                        }),
                      ),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: KSpace.md),
                        KBanner(title: 'Création impossible', message: state.errorMessage!, tone: KTone.danger),
                      ],
                      const SizedBox(height: KSpace.lg),
                      KAsyncButton(
                        label: 'Créer mon compte',
                        busyLabel: 'Création du compte…',
                        icon: Icons.person_add_alt_1_rounded,
                        onPressed: busy ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
