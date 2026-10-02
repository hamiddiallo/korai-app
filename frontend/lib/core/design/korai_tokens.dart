import 'package:flutter/material.dart';

/// Familles de polices de la direction « Korai Onde ».
///
/// Les fichiers doivent être embarqués dans `assets/fonts/` et déclarés dans
/// `pubspec.yaml` (l'app doit fonctionner hors ligne dès le premier lancement).
/// Tant qu'ils ne le sont pas, Flutter retombe silencieusement sur la police
/// système : aucun plantage.
class KFonts {
  const KFonts._();

  /// Titres d'écran et grands chiffres.
  static const display = 'Sora';

  /// Texte courant et interface (lisibilité en conditions difficiles).
  static const body = 'AtkinsonHyperlegibleNext';

  /// Matricules, heures, scores : chiffres à chasse fixe.
  static const mono = 'AtkinsonHyperlegibleMono';
}

/// Espacements sur une grille de 4.
class KSpace {
  const KSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Marge latérale des écrans.
  static const double gutter = 20;
}

/// Rayons : contrôles, cartes, feuilles, pilules.
class KRadius {
  const KRadius._();

  static const double control = 12;
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;

  static final BorderRadius controlAll = BorderRadius.circular(control);
  static final BorderRadius cardAll = BorderRadius.circular(card);
  static final BorderRadius sheetAll = BorderRadius.circular(sheet);
  static final BorderRadius pillAll = BorderRadius.circular(pill);
}

/// Durées et courbes : une seule cadence pour toute l'app.
class KMotion {
  const KMotion._();

  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
  static const exit = Duration(milliseconds: 180);

  static const enter = Curves.easeOutCubic;
  static const leave = Curves.easeInCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// `true` si le système demande de réduire les animations.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Durée à utiliser : zéro quand les animations sont réduites.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Tonalités sémantiques partagées par les pastilles, bannières et états.
enum KTone { neutral, brand, success, warning, danger, info, ai }

/// Jetons de couleur de Korai, clair et sombre.
///
/// Toute couleur d'écran passe par ces jetons (`context.k`) : plus de valeurs
/// codées en dur dans les écrans.
@immutable
class KoraiColors extends ThemeExtension<KoraiColors> {
  const KoraiColors({
    required this.ink,
    required this.inkMuted,
    required this.brand,
    required this.onBrand,
    required this.lagoon,
    required this.onLagoon,
    required this.mist,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.aqua,
    required this.aquaInk,
    required this.aquaBg,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
    required this.success,
    required this.successBg,
    required this.successInk,
    required this.warning,
    required this.warningBg,
    required this.warningInk,
    required this.danger,
    required this.dangerBg,
    required this.dangerInk,
    required this.info,
    required this.infoBg,
    required this.infoInk,
    required this.neutralBg,
  });

  /// Texte principal.
  final Color ink;

  /// Texte secondaire (contraste ≥ 4,5:1 sur les surfaces).
  final Color inkMuted;

  /// Couleur de marque, actions principales.
  final Color brand;
  final Color onBrand;

  /// Surfaces teintées, états sélectionnés.
  final Color lagoon;
  final Color onLagoon;

  /// Fond de l'app.
  final Color mist;

  /// Cartes et feuilles.
  final Color surface;

  /// Surface secondaire (champs désactivés, pistes).
  final Color surfaceAlt;

  /// Traits et bordures.
  final Color line;

  /// Réservé aux contenus produits par l'IA.
  final Color aqua;
  final Color aquaInk;
  final Color aquaBg;

  /// Surface sombre « encre » (carte principale, démarrage).
  final Color hero;
  final Color onHero;
  final Color onHeroMuted;

  final Color success;
  final Color successBg;
  final Color successInk;
  final Color warning;
  final Color warningBg;
  final Color warningInk;
  final Color danger;
  final Color dangerBg;
  final Color dangerInk;
  final Color info;
  final Color infoBg;
  final Color infoInk;
  final Color neutralBg;

  static const light = KoraiColors(
    ink: Color(0xFF0E2E35),
    inkMuted: Color(0xFF4F6468),
    brand: Color(0xFF006D77),
    onBrand: Color(0xFFFFFFFF),
    lagoon: Color(0xFFDDEFEC),
    onLagoon: Color(0xFF00555D),
    mist: Color(0xFFF3F6F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE7EFED),
    line: Color(0xFFD5E1DF),
    aqua: Color(0xFF1FA595),
    aquaInk: Color(0xFF137A6E),
    aquaBg: Color(0xFFE1F4F1),
    hero: Color(0xFF0E2E35),
    onHero: Color(0xFFE6F0EE),
    onHeroMuted: Color(0xFFA9C2C0),
    success: Color(0xFF2F855A),
    successBg: Color(0xFFE2F2E9),
    successInk: Color(0xFF256B47),
    warning: Color(0xFFC8891C),
    warningBg: Color(0xFFFBF0DA),
    warningInk: Color(0xFF7F520C),
    danger: Color(0xFFC53030),
    dangerBg: Color(0xFFFBE4E2),
    dangerInk: Color(0xFFA82424),
    info: Color(0xFF2B6CB0),
    infoBg: Color(0xFFE6EFFA),
    infoInk: Color(0xFF1F4F85),
    neutralBg: Color(0xFFE9EFEE),
  );

  static const dark = KoraiColors(
    ink: Color(0xFFE4EEEC),
    inkMuted: Color(0xFF9FB7B4),
    brand: Color(0xFF4FB7BF),
    onBrand: Color(0xFF032B30),
    lagoon: Color(0xFF153A3F),
    onLagoon: Color(0xFFBFEDEF),
    mist: Color(0xFF0B1C20),
    surface: Color(0xFF132A2F),
    surfaceAlt: Color(0xFF1A353B),
    line: Color(0xFF28474F),
    aqua: Color(0xFF3CC7B5),
    aquaInk: Color(0xFF7FE0D2),
    aquaBg: Color(0xFF123A36),
    hero: Color(0xFF06272C),
    onHero: Color(0xFFE6F0EE),
    onHeroMuted: Color(0xFF9DB6B4),
    success: Color(0xFF5CC389),
    successBg: Color(0xFF16352A),
    successInk: Color(0xFF8FDBAE),
    warning: Color(0xFFE3A949),
    warningBg: Color(0xFF3A2E14),
    warningInk: Color(0xFFF1CB85),
    danger: Color(0xFFF07167),
    dangerBg: Color(0xFF3A1C1C),
    dangerInk: Color(0xFFFFB3AC),
    info: Color(0xFF7EB2EA),
    infoBg: Color(0xFF14273D),
    infoInk: Color(0xFFB9D6F5),
    neutralBg: Color(0xFF1A353B),
  );

  /// Couleurs (fond, texte, accent) d'une tonalité.
  ({Color bg, Color fg, Color accent}) tone(KTone tone) => switch (tone) {
        KTone.neutral => (bg: neutralBg, fg: inkMuted, accent: inkMuted),
        KTone.brand => (bg: lagoon, fg: onLagoon, accent: brand),
        KTone.success => (bg: successBg, fg: successInk, accent: success),
        KTone.warning => (bg: warningBg, fg: warningInk, accent: warning),
        KTone.danger => (bg: dangerBg, fg: dangerInk, accent: danger),
        KTone.info => (bg: infoBg, fg: infoInk, accent: info),
        KTone.ai => (bg: aquaBg, fg: aquaInk, accent: aqua),
      };

  @override
  KoraiColors copyWith({Color? ink, Color? brand}) => KoraiColors(
        ink: ink ?? this.ink,
        inkMuted: inkMuted,
        brand: brand ?? this.brand,
        onBrand: onBrand,
        lagoon: lagoon,
        onLagoon: onLagoon,
        mist: mist,
        surface: surface,
        surfaceAlt: surfaceAlt,
        line: line,
        aqua: aqua,
        aquaInk: aquaInk,
        aquaBg: aquaBg,
        hero: hero,
        onHero: onHero,
        onHeroMuted: onHeroMuted,
        success: success,
        successBg: successBg,
        successInk: successInk,
        warning: warning,
        warningBg: warningBg,
        warningInk: warningInk,
        danger: danger,
        dangerBg: dangerBg,
        dangerInk: dangerInk,
        info: info,
        infoBg: infoBg,
        infoInk: infoInk,
        neutralBg: neutralBg,
      );

  @override
  KoraiColors lerp(ThemeExtension<KoraiColors>? other, double t) {
    if (other is! KoraiColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return KoraiColors(
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      brand: l(brand, other.brand),
      onBrand: l(onBrand, other.onBrand),
      lagoon: l(lagoon, other.lagoon),
      onLagoon: l(onLagoon, other.onLagoon),
      mist: l(mist, other.mist),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      line: l(line, other.line),
      aqua: l(aqua, other.aqua),
      aquaInk: l(aquaInk, other.aquaInk),
      aquaBg: l(aquaBg, other.aquaBg),
      hero: l(hero, other.hero),
      onHero: l(onHero, other.onHero),
      onHeroMuted: l(onHeroMuted, other.onHeroMuted),
      success: l(success, other.success),
      successBg: l(successBg, other.successBg),
      successInk: l(successInk, other.successInk),
      warning: l(warning, other.warning),
      warningBg: l(warningBg, other.warningBg),
      warningInk: l(warningInk, other.warningInk),
      danger: l(danger, other.danger),
      dangerBg: l(dangerBg, other.dangerBg),
      dangerInk: l(dangerInk, other.dangerInk),
      info: l(info, other.info),
      infoBg: l(infoBg, other.infoBg),
      infoInk: l(infoInk, other.infoInk),
      neutralBg: l(neutralBg, other.neutralBg),
    );
  }
}

extension KoraiThemeX on BuildContext {
  /// Jetons de couleur Korai du thème courant.
  KoraiColors get k =>
      Theme.of(this).extension<KoraiColors>() ?? KoraiColors.light;

  TextTheme get text => Theme.of(this).textTheme;
}
