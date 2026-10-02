import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/design.dart';
import 'app_lock.dart';
import 'biometric_service.dart';

IconData unlockIcon(UnlockMethod method) => switch (method) {
      UnlockMethod.faceId || UnlockMethod.face => Icons.face_rounded,
      UnlockMethod.touchId || UnlockMethod.fingerprint || UnlockMethod.biometric => Icons.fingerprint_rounded,
      UnlockMethod.deviceCode => Icons.pin_outlined,
      UnlockMethod.none => Icons.lock_outline_rounded,
    };

/// Logo Korai sur fond encre (verrou, écran masqué).
class _KoraiMark extends StatelessWidget {
  const _KoraiMark();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(color: k.onHero, borderRadius: BorderRadius.circular(24)),
      child: Icon(Icons.hearing_rounded, size: 44, color: KoraiColors.light.brand),
    );
  }
}

/// Écran de verrouillage. Placé au-dessus de toute l'application (hors du
/// Navigator) : ni dialogue ni info-bulle ici.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.userName, required this.onUsePassword});

  final String userName;

  /// Déconnexion, pour se reconnecter avec e-mail et mot de passe.
  final VoidCallback onUsePassword;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    // Propose Face ID tout de suite, une fois l'écran affiché.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        context.read<AppLockCubit>().unlock();
      }
    });
  }

  String get _firstName {
    final parts = widget.userName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? '' : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return BlocBuilder<AppLockCubit, AppLockState>(
      builder: (context, lock) {
        final canUnlock = lock.method.available;
        return Material(
          color: k.hero,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.lg, KSpace.lg, KSpace.lg, KSpace.md),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _KoraiMark(),
                  const SizedBox(height: KSpace.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      'Korai est verrouillé',
                      textAlign: TextAlign.center,
                      style: context.text.headlineSmall?.copyWith(color: k.onHero),
                    ),
                  ),
                  const SizedBox(height: KSpace.xs),
                  Text(
                    _firstName.isEmpty
                        ? 'Déverrouillez pour retrouver vos dossiers.'
                        : 'Bonjour $_firstName. Déverrouillez pour retrouver vos dossiers.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(color: k.onHeroMuted),
                  ),
                  const SizedBox(height: KSpace.lg),
                  AnimatedSwitcher(
                    duration: KMotion.of(context, KMotion.base),
                    child: lock.message == null && canUnlock
                        ? const SizedBox(key: ValueKey('none'), height: 0)
                        : Semantics(
                            key: ValueKey(lock.message),
                            liveRegion: true,
                            child: KBanner(
                              tone: KTone.warning,
                              message: lock.message ??
                                  'Aucun code, visage ou empreinte n’est configuré sur ce téléphone. '
                                      'Reconnectez-vous avec votre mot de passe.',
                            ),
                          ),
                  ),
                  const Spacer(flex: 3),
                  if (canUnlock)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: k.onHero, foregroundColor: k.hero),
                        onPressed: lock.unlocking ? null : () => context.read<AppLockCubit>().unlock(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (lock.unlocking)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: k.hero),
                              )
                            else
                              Icon(unlockIcon(lock.method), size: 22),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                lock.unlocking ? 'Vérification…' : lock.method.buttonLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: KSpace.xs),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: k.onHero),
                      onPressed: lock.unlocking ? null : widget.onUsePassword,
                      child: const Text('Me reconnecter avec mon mot de passe'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cache le contenu quand l'application passe en arrière-plan (aperçu du
/// sélecteur d'applications) : aucun dossier patient n'y apparaît.
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.k.hero,
      child: const Center(child: _KoraiMark()),
    );
  }
}
