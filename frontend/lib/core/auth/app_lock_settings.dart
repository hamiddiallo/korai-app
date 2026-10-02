import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/design.dart';
import 'app_lock.dart';
import 'biometric_service.dart';
import 'lock_screen.dart';

/// Carte « Verrouillage de l'application » du profil : activer, désactiver,
/// choisir le délai.
class AppLockSettingsCard extends StatelessWidget {
  const AppLockSettingsCard({super.key});

  Future<void> _toggle(BuildContext context, bool enable) async {
    final cubit = context.read<AppLockCubit>();
    final error = enable ? await cubit.enable() : await cubit.disable();
    if (!context.mounted) return;
    if (error != null) {
      KSnack.show(context, error, tone: KTone.warning);
    } else if (cubit.state.enabled == enable) {
      KSnack.success(
        context,
        enable
            ? 'Verrouillage activé : Korai se verrouillera après ${appLockTimeoutLabel(cubit.state.timeout)} en arrière-plan.'
            : 'Verrouillage désactivé.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return BlocBuilder<AppLockCubit, AppLockState>(
      builder: (context, lock) {
        return KCard(
          padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.xs, KSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(unlockIcon(lock.method), color: k.brand),
                  const SizedBox(width: KSpace.xs),
                  Expanded(child: Text('Verrouillage de l’application', style: context.text.titleMedium)),
                ],
              ),
              const SizedBox(height: 4),
              if (!lock.method.available)
                Padding(
                  padding: const EdgeInsets.only(right: KSpace.xs, bottom: KSpace.xs),
                  child: Text(
                    'Ajoutez un code de verrouillage, Face ID ou une empreinte dans les réglages du téléphone '
                    'pour protéger Korai.',
                    style: context.text.bodySmall,
                  ),
                )
              else ...[
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(right: KSpace.xs),
                  title: Text('Déverrouiller avec ${lock.method.label}'),
                  subtitle: Text(
                    lock.enabled
                        ? 'Demandé à l’ouverture et après ${appLockTimeoutLabel(lock.timeout)} en arrière-plan.'
                        : 'Protège les dossiers si quelqu’un prend votre téléphone.',
                  ),
                  value: lock.enabled,
                  onChanged: lock.unlocking ? null : (v) => _toggle(context, v),
                ),
                if (lock.enabled) ...[
                  Text('Verrouiller après', style: context.text.labelMedium?.copyWith(color: k.inkMuted)),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: KSpace.xs, bottom: KSpace.xs),
                    child: KSegmented<Duration>(
                      segments: [
                        for (final d in AppLockCubit.timeouts) KSegment(value: d, label: appLockTimeoutLabel(d)),
                      ],
                      value: lock.timeout,
                      onChanged: (d) => context.read<AppLockCubit>().setTimeout(d),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Proposée juste après une connexion par mot de passe.
Future<void> showAppLockOffer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _AppLockOfferSheet(),
  );
}

class _AppLockOfferSheet extends StatefulWidget {
  const _AppLockOfferSheet();

  @override
  State<_AppLockOfferSheet> createState() => _AppLockOfferSheetState();
}

class _AppLockOfferSheetState extends State<_AppLockOfferSheet> {
  String? _error;

  Future<void> _enable() async {
    final cubit = context.read<AppLockCubit>();
    final error = await cubit.enable();
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (!cubit.state.enabled) return; // annulé : la feuille reste ouverte
    KSnack.success(
      context,
      'Verrouillage activé : Korai se verrouillera après ${appLockTimeoutLabel(cubit.state.timeout)} en arrière-plan.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final lock = context.watch<AppLockCubit>().state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: k.lagoon, shape: BoxShape.circle),
              child: Icon(unlockIcon(lock.method), size: 34, color: k.brand),
            ),
          ),
          const SizedBox(height: KSpace.md),
          Text(
            'Protéger Korai avec ${lock.method.label} ?',
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            'Korai se verrouillera à l’ouverture et après ${appLockTimeoutLabel(lock.timeout)} en arrière-plan. '
            'Vous le rouvrirez avec ${lock.method.label}, sans ressaisir votre mot de passe. '
            'La vérification se fait sur le téléphone : rien n’est envoyé au serveur.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
          ),
          if (_error != null) ...[
            const SizedBox(height: KSpace.md),
            KBanner(tone: KTone.warning, message: _error!),
          ],
          const SizedBox(height: KSpace.lg),
          KAsyncButton(
            label: 'Activer',
            busyLabel: 'Vérification…',
            icon: unlockIcon(lock.method),
            onPressed: _enable,
          ),
          const SizedBox(height: KSpace.xs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
          Text(
            'Modifiable à tout moment dans votre profil.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}
