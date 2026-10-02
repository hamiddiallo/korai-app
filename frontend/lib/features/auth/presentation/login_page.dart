import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import 'patient_register_page.dart';
import 'professional_register_page.dart';

/// Connexion unique : le rôle (soignant, spécialiste, patient, admin) est
/// déterminé par le serveur, l'utilisateur n'a rien à choisir.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final AuthCubit session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.session.clearError();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.session.login(_email.text.trim(), _password.text);
  }

  void _openRegister(Widget page) {
    widget.session.clearError();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return BlocBuilder<AuthCubit, AuthState>(
      bloc: widget.session,
      builder: (context, state) {
        final busy = state.isSubmitting;
        return Scaffold(
          body: SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(KSpace.lg, KSpace.lg, KSpace.lg, KSpace.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _BrandHeader(),
                        const SizedBox(height: KSpace.xl),
                        Text('Connexion', style: context.text.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Un seul accès pour les soignants, les spécialistes et les patients.',
                          style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
                        ),
                        const SizedBox(height: KSpace.lg),
                        AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                                  autocorrect: false,
                                  enabled: !busy,
                                  decoration: const InputDecoration(
                                    labelText: 'Adresse e-mail',
                                    prefixIcon: Icon(Icons.mail_outline_rounded),
                                  ),
                                  validator: KValidators.email,
                                ),
                                const SizedBox(height: KSpace.sm),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  enabled: !busy,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => KValidators.required(v, 'Mot de passe'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: KSpace.md),
                          _LoginError(message: state.errorMessage!),
                        ],
                        const SizedBox(height: KSpace.lg),
                        FilledButton(
                          onPressed: busy ? null : _submit,
                          style: busy
                              ? FilledButton.styleFrom(
                                  disabledBackgroundColor: k.brand.withValues(alpha: 0.85),
                                  disabledForegroundColor: k.onBrand,
                                )
                              : null,
                          child: busy
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.4, color: k.onBrand),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Connexion…'),
                                  ],
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.login_rounded),
                                    SizedBox(width: 8),
                                    Text('Se connecter'),
                                  ],
                                ),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: KSpace.md),
                          _DemoAccounts(
                            enabled: !busy,
                            onPick: (email) {
                              widget.session.clearError();
                              setState(() {
                                _email.text = email;
                                _password.text = 'Password123!';
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: KSpace.xl),
                        Text('Pas encore de compte ?', style: context.text.titleMedium),
                        const SizedBox(height: KSpace.sm),
                        _RegisterChoice(
                          icon: Icons.person_outline_rounded,
                          title: 'Je suis patient',
                          subtitle: 'Préparez votre consultation et retrouvez vos comptes-rendus.',
                          onTap: busy ? null : () => _openRegister(PatientRegisterPage(session: widget.session)),
                        ),
                        const SizedBox(height: KSpace.xs),
                        _RegisterChoice(
                          icon: Icons.medical_services_outlined,
                          title: 'Je suis professionnel de santé',
                          subtitle: 'Infirmier·ère ou spécialiste ORL, avec votre matricule.',
                          onTap: busy ? null : () => _openRegister(ProfessionalRegisterPage(session: widget.session)),
                        ),
                      ],
                    ),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(color: k.hero, borderRadius: BorderRadius.circular(22)),
          child: Icon(Icons.hearing_rounded, size: 38, color: k.onHero),
        ),
        const SizedBox(height: KSpace.sm),
        Text(
          'Korai',
          style: TextStyle(
            fontFamily: KFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 34,
            letterSpacing: -0.6,
            color: k.ink,
          ),
        ),
        Text('Assistant ORL', style: context.text.bodyMedium?.copyWith(color: k.inkMuted)),
      ],
    );
  }
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final lower = message.toLowerCase();
    final (title, tone) = lower.contains('attente')
        ? ('Compte en attente de validation', KTone.warning)
        : lower.contains('refusée')
            ? ('Inscription refusée', KTone.danger)
            : (lower.contains('connexion') || lower.contains('réseau'))
                ? ('Serveur injoignable', KTone.warning)
                : ('Connexion impossible', KTone.danger);
    return KBanner(title: title, message: message, tone: tone);
  }
}

class _RegisterChoice extends StatelessWidget {
  const _RegisterChoice({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(KSpace.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: k.lagoon, shape: BoxShape.circle),
            child: Icon(icon, color: k.brand),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: k.inkMuted),
        ],
      ),
    );
  }
}

/// Comptes de démonstration du seed backend. Visible uniquement dans les
/// builds de debug : `kDebugMode` est une constante, ce bloc est retiré des
/// versions de production.
class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({required this.onPick, required this.enabled});

  final ValueChanged<String> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const accounts = [
      ('Infirmier·ère', 'nurse@korai.local'),
      ('Spécialiste', 'orl@korai.local'),
      ('Admin', 'admin@korai.local'),
      ('Patient', 'patient@korai.local'),
    ];
    return Container(
      padding: const EdgeInsets.all(KSpace.sm),
      decoration: BoxDecoration(
        borderRadius: KRadius.controlAll,
        border: Border.all(color: k.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comptes de démonstration (debug)', style: context.text.labelSmall?.copyWith(color: k.inkMuted)),
          const SizedBox(height: KSpace.xs),
          Wrap(
            spacing: KSpace.xs,
            runSpacing: KSpace.xs,
            children: [
              for (final (label, email) in accounts)
                ActionChip(
                  label: Text(label),
                  onPressed: enabled ? () => onPick(email) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
