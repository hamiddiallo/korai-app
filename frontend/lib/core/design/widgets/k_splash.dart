import 'package:flutter/material.dart';

import '../korai_tokens.dart';

/// Écran de démarrage : l'onde se propage autour du logo pendant la
/// restauration de session. Aucun appel réseau : il fonctionne hors ligne.
class KoraiSplash extends StatefulWidget {
  const KoraiSplash({super.key, this.message = 'Restauration de la session…'});

  final String message;

  @override
  State<KoraiSplash> createState() => _KoraiSplashState();
}

class _KoraiSplashState extends State<KoraiSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KMotion.reduced(context)) {
      _c.stop();
      _c.value = 0.35;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Scaffold(
      backgroundColor: k.hero,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, child) => Stack(
                          alignment: Alignment.center,
                          children: [
                            for (var i = 0; i < 3; i++) _ring(k, (_c.value + i / 3) % 1),
                            child!,
                          ],
                        ),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(color: k.onHero, borderRadius: BorderRadius.circular(26)),
                          child: Icon(Icons.hearing_rounded, size: 50, color: KoraiColors.light.brand),
                        ),
                      ),
                    ),
                    const SizedBox(height: KSpace.md),
                    Text(
                      'Korai',
                      style: TextStyle(
                        fontFamily: KFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        letterSpacing: -0.8,
                        color: k.onHero,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Assistant ORL', style: context.text.bodyLarge?.copyWith(color: k.onHeroMuted)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: KSpace.xl),
              child: Semantics(
                liveRegion: true,
                child: Text(widget.message, style: context.text.bodyMedium?.copyWith(color: k.onHeroMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(KoraiColors k, double t) {
    final eased = Curves.easeOutCubic.transform(t);
    final size = 84 + eased * 106;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: k.aqua.withValues(alpha: (1 - t) * 0.7), width: 1.6),
        ),
      ),
    );
  }
}
