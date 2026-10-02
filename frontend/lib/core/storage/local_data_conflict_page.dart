import 'package:flutter/material.dart';

import '../design/design.dart';

/// Un autre compte a laissé des données non envoyées sur ce téléphone : le
/// compte connecté ne peut ni les voir ni les envoyer à sa place.
class LocalDataConflictPage extends StatelessWidget {
  const LocalDataConflictPage({
    super.key,
    required this.ownerName,
    required this.unsentCount,
    required this.onLogout,
    required this.onDiscard,
  });

  final String ownerName;
  final int unsentCount;
  final VoidCallback onLogout;

  /// Efface les données de l'autre compte (après confirmation).
  final Future<void> Function() onDiscard;

  bool get _one => unsentCount == 1;

  Future<void> _confirmDiscard(BuildContext context) async {
    final ok = await showKConfirm(
      context,
      title: 'Effacer les données de $ownerName ?',
      message: '${_one ? 'L’élément non envoyé sera définitivement perdu' : 'Les $unsentCount éléments non envoyés seront définitivement perdus'} '
          '(consultations, fiches patients). '
          'Faites-le seulement si $ownerName ne peut pas se reconnecter sur ce téléphone.',
      confirmLabel: 'Effacer définitivement',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await onDiscard();
    } catch (e) {
      if (context.mounted) KSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(KSpace.lg, KSpace.xl, KSpace.lg, KSpace.lg),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: k.warningBg, shape: BoxShape.circle),
                child: Icon(Icons.phonelink_lock_rounded, size: 36, color: k.warningInk),
              ),
            ),
            const SizedBox(height: KSpace.lg),
            Semantics(
              header: true,
              child: Text(
                'Données d’un autre compte sur ce téléphone',
                textAlign: TextAlign.center,
                style: context.text.headlineSmall,
              ),
            ),
            const SizedBox(height: KSpace.sm),
            Text(
              'Ce téléphone contient ${_one ? '1 élément non envoyé enregistré' : '$unsentCount éléments non envoyés enregistrés'} '
              'par $ownerName. '
              'Pour protéger ces dossiers, seul $ownerName peut les consulter et les envoyer.',
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: k.inkMuted),
            ),
            const SizedBox(height: KSpace.lg),
            KBanner(
              tone: KTone.info,
              icon: Icons.tips_and_updates_outlined,
              title: 'Que faire ?',
              message:
                  'Demandez à $ownerName de se reconnecter sur ce téléphone avec du réseau : ses données partiront '
                  'automatiquement. Vous pourrez ensuite utiliser Korai avec votre compte.',
            ),
            const SizedBox(height: KSpace.xl),
            FilledButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Me déconnecter'),
            ),
            const SizedBox(height: KSpace.xs),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: k.danger),
              onPressed: () => _confirmDiscard(context),
              child: Text('Effacer les données de $ownerName'),
            ),
          ],
        ),
      ),
    );
  }
}
