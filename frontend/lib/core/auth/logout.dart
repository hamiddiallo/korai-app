import 'package:flutter/material.dart';

import '../design/design.dart';
import '../storage/local_data_guard.dart';
import 'session_controller.dart';

/// Demande confirmation, puis déconnecte. Prévient s'il reste des données non
/// envoyées : elles partiront à la prochaine connexion de ce même compte, et
/// aucun autre compte ne pourra utiliser Korai sur ce téléphone d'ici là.
Future<void> confirmAndLogout(BuildContext context, AuthCubit session) async {
  var unsent = 0;
  try {
    unsent = await LocalDataGuard.instance.countUnsent();
  } catch (_) {
    // Base locale indisponible : rien en attente à signaler.
  }
  if (!context.mounted) return;
  final pending = unsent == 1
      ? '1 élément n’a pas encore été envoyé. Il reste sur ce téléphone et partira'
      : '$unsent éléments n’ont pas encore été envoyés. Ils restent sur ce téléphone et partiront';
  final ok = await showKConfirm(
    context,
    title: 'Se déconnecter ?',
    message: unsent == 0
        ? 'Vous devrez saisir à nouveau votre e-mail et votre mot de passe pour revenir.'
        : '$pending à votre prochaine connexion. D’ici là, un autre compte ne pourra pas utiliser Korai sur ce téléphone.',
    confirmLabel: 'Se déconnecter',
  );
  // Les pages ouvertes par-dessus l'accueil sont fermées par KoraiApp à la
  // déconnexion (même chose quand la session expire).
  if (ok) await session.logout();
}

/// Action de déconnexion discrète, séparée des actions courantes.
class KLogoutButton extends StatelessWidget {
  const KLogoutButton({super.key, required this.session});

  final AuthCubit session;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return TextButton.icon(
      onPressed: () => confirmAndLogout(context, session),
      style: TextButton.styleFrom(foregroundColor: k.danger),
      icon: const Icon(Icons.logout_rounded, size: 20),
      label: const Text('Se déconnecter'),
    );
  }
}
