import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/session_controller.dart';

/// Inscription des professionnels de santé : infirmier (validation requise par
/// l'encadrant) ou spécialiste (vérifié par matricule, connexion immédiate).
class ProfessionalRegisterPage extends StatefulWidget {
  const ProfessionalRegisterPage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<ProfessionalRegisterPage> createState() =>
      _ProfessionalRegisterPageState();
}

enum _Role { nurse, specialist }

class _ProfessionalRegisterPageState extends State<ProfessionalRegisterPage> {
  _Role _role = _Role.nurse;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _healthFacility = TextEditingController();
  final _professionalId = TextEditingController();
  final _matricule = TextEditingController(); // spécialiste : son matricule
  final _supervisorMatricule = TextEditingController(); // infirmier : encadrant

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

  String? _validate() {
    if (_fullName.text.trim().length < 2) return 'Nom complet requis.';
    if (!_email.text.contains('@')) return 'Email invalide.';
    if (_password.text.length < 8) {
      return 'Mot de passe : 8 caractères minimum.';
    }
    if (_role == _Role.nurse) {
      if (_healthFacility.text.trim().length < 2) {
        return 'Structure de santé requise.';
      }
      if (_supervisorMatricule.text.trim().isEmpty) {
        return "Matricule de l'encadrant requis.";
      }
    } else {
      if (_matricule.text.trim().isEmpty) return 'Votre matricule est requis.';
    }
    return null;
  }

  Future<void> _submit() async {
    final localError = _validate();
    if (localError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localError), backgroundColor: Colors.red),
      );
      return;
    }

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
      if (!mounted) return;
      if (message != null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFF006D77), size: 40),
            title: const Text('Inscription enregistrée'),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Compris'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context); // retour au login
      }
    } else {
      final ok = await widget.session.registerSpecialist(
        fullName: _fullName.text,
        email: _email.text,
        password: _password.text,
        matricule: _matricule.text,
        phone: _phone.text,
        healthFacility: _healthFacility.text,
      );
      // Succès → la session est authentifiée, l'app bascule sur l'accueil :
      // on retire la page d'inscription de la pile.
      if (ok && mounted && Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.session,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inscription professionnel'),
          backgroundColor: const Color(0xFFE8F1F2),
          foregroundColor: const Color(0xFF006D77),
        ),
        body: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final isNurse = _role == _Role.nurse;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_Role>(
                    segments: const [
                      ButtonSegment(
                          value: _Role.nurse,
                          label: Text('Infirmier'),
                          icon: Icon(Icons.medical_services_outlined)),
                      ButtonSegment(
                          value: _Role.specialist,
                          label: Text('Spécialiste'),
                          icon: Icon(Icons.verified_user_outlined)),
                    ],
                    selected: {_role},
                    onSelectionChanged: (s) =>
                        setState(() => _role = s.first),
                  ),
                  const SizedBox(height: 16),
                  _field(_fullName, 'Nom complet', Icons.person_outline),
                  _field(_email, 'Email', Icons.email_outlined,
                      keyboard: TextInputType.emailAddress),
                  _field(_password, 'Mot de passe (8+ caractères)',
                      Icons.lock_outline,
                      obscure: true),
                  _field(_phone, 'Téléphone (optionnel)', Icons.phone_outlined,
                      keyboard: TextInputType.phone),
                  if (isNurse) ...[
                    _field(_healthFacility, 'Structure de santé',
                        Icons.local_hospital_outlined),
                    _field(_professionalId, 'Identifiant pro. (optionnel)',
                        Icons.badge_outlined),
                    _field(_supervisorMatricule,
                        "Matricule de l'expert encadrant", Icons.key_outlined),
                    const Padding(
                      padding: EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        'Votre inscription devra être validée par cet expert.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ] else ...[
                    _field(_matricule, 'Votre matricule', Icons.key_outlined),
                    _field(_healthFacility,
                        'Structure de santé (optionnel)',
                        Icons.local_hospital_outlined),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(state.errorMessage!,
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF006D77),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: state.isSubmitting ? null : _submit,
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isNurse
                            ? "Envoyer ma demande d'inscription"
                            : 'Créer mon compte spécialiste'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
