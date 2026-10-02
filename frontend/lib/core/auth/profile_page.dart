import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/design.dart';
import 'app_lock_settings.dart';
import 'logout.dart';
import 'profile_sheets.dart';
import 'session_controller.dart';

/// Profil de l'utilisateur connecté (soignant, spécialiste). La déconnexion
/// est une action discrète, séparée des actions courantes.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.session, this.embedded = false});

  final AuthCubit session;

  /// `true` quand la page est un onglet (pas de barre d'application).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = BlocBuilder<AuthCubit, AuthState>(
      bloc: session,
      builder: (context, state) {
        final user = state.user;
        final k = context.k;
        return ListView(
          padding: EdgeInsets.fromLTRB(KSpace.gutter, embedded ? KSpace.md : KSpace.xs, KSpace.gutter, 120),
          children: [
            Center(child: KInitialsAvatar(name: user?.fullName ?? '?', size: 84)),
            const SizedBox(height: KSpace.sm),
            Text(user?.fullName ?? '', textAlign: TextAlign.center, style: context.text.headlineSmall),
            Text(user?.email ?? '', textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: k.inkMuted)),
            const SizedBox(height: KSpace.xs),
            Center(child: KPill(label: KLabels.role(user?.role), icon: Icons.badge_outlined, tone: KTone.brand)),
            const SizedBox(height: KSpace.lg),
            KCard(
              child: Column(
                children: [
                  KInfoRow(label: 'Téléphone', value: _or(user?.phone)),
                  KInfoRow(label: 'Structure', value: _or(user?.healthFacility)),
                  KInfoRow(label: 'Identifiant pro.', value: _or(user?.professionalId)),
                ],
              ),
            ),
            const SizedBox(height: KSpace.sm),
            const AppLockSettingsCard(),
            const SizedBox(height: KSpace.md),
            OutlinedButton.icon(
              onPressed: () => showEditProfileSheet(context, session),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifier mon profil'),
            ),
            const SizedBox(height: KSpace.xs),
            OutlinedButton.icon(
              onPressed: () => showChangePasswordSheet(context, session),
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Changer le mot de passe'),
            ),
            const SizedBox(height: KSpace.xl),
            Center(child: KLogoutButton(session: session)),
          ],
        );
      },
    );
    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Mon profil')), body: body);
  }

  static String _or(String? v) => (v == null || v.trim().isEmpty) ? 'Non renseigné' : v;
}
