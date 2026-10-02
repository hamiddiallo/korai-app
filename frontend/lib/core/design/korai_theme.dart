import 'package:flutter/material.dart';

import 'korai_tokens.dart';

/// Thème unique de Korai, partagé par tous les rôles.
class KoraiTheme {
  const KoraiTheme._();

  static ThemeData light() => _build(Brightness.light, KoraiColors.light);
  static ThemeData dark() => _build(Brightness.dark, KoraiColors.dark);

  static ThemeData _build(Brightness brightness, KoraiColors k) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: k.brand,
      onPrimary: k.onBrand,
      primaryContainer: k.lagoon,
      onPrimaryContainer: k.onLagoon,
      secondary: k.aqua,
      onSecondary: isDark ? const Color(0xFF03312B) : Colors.white,
      secondaryContainer: k.aquaBg,
      onSecondaryContainer: k.aquaInk,
      tertiary: k.hero,
      onTertiary: k.onHero,
      error: k.danger,
      onError: isDark ? const Color(0xFF3A0707) : Colors.white,
      errorContainer: k.dangerBg,
      onErrorContainer: k.dangerInk,
      surface: k.mist,
      onSurface: k.ink,
      onSurfaceVariant: k.inkMuted,
      surfaceContainerLowest: k.surface,
      surfaceContainerLow: k.surface,
      surfaceContainer: k.surfaceAlt,
      surfaceContainerHigh: k.surfaceAlt,
      surfaceContainerHighest: k.surfaceAlt,
      outline: k.inkMuted.withValues(alpha: 0.55),
      outlineVariant: k.line,
      inverseSurface: k.hero,
      onInverseSurface: k.onHero,
      inversePrimary: isDark ? KoraiColors.light.brand : KoraiColors.dark.brand,
      shadow: const Color(0xFF062126),
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    final text = _textTheme(k);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: KRadius.controlAll,
          borderSide: BorderSide(color: c, width: w),
        );

    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: k.mist,
      canvasColor: k.mist,
      fontFamily: KFonts.body,
      textTheme: text,
      extensions: [k],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: k.mist,
        foregroundColor: k.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: k.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: KRadius.cardAll,
          side: BorderSide(color: k.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: buttonShape,
          textStyle: text.labelLarge,
          backgroundColor: k.brand,
          foregroundColor: k.onBrand,
          disabledBackgroundColor: k.surfaceAlt,
          disabledForegroundColor: k.inkMuted,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: buttonShape,
          textStyle: text.labelLarge,
          foregroundColor: k.brand,
          side: BorderSide(color: k.line, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          textStyle: text.labelLarge,
          foregroundColor: k.brand,
          shape: buttonShape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: buttonShape,
          elevation: 0,
          textStyle: text.labelLarge,
          backgroundColor: k.brand,
          foregroundColor: k.onBrand,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: k.ink,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: k.brand,
        foregroundColor: k.onBrand,
        elevation: 2,
        extendedTextStyle: text.labelLarge,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: k.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: border(k.line),
        enabledBorder: border(k.line),
        focusedBorder: border(k.brand, 2),
        errorBorder: border(k.danger),
        focusedErrorBorder: border(k.danger, 2),
        disabledBorder: border(k.line.withValues(alpha: 0.5)),
        labelStyle: text.bodyMedium?.copyWith(color: k.inkMuted),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: k.brand),
        hintStyle: text.bodyMedium?.copyWith(color: k.inkMuted),
        helperStyle: text.bodySmall?.copyWith(color: k.inkMuted),
        errorStyle: text.bodySmall?.copyWith(color: k.danger),
        errorMaxLines: 3,
        helperMaxLines: 3,
        prefixIconColor: k.inkMuted,
        suffixIconColor: k.inkMuted,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: k.line),
        backgroundColor: k.surface,
        selectedColor: k.brand,
        checkmarkColor: k.onBrand,
        labelStyle: text.labelMedium?.copyWith(color: k.ink),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: k.onBrand),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(BorderSide(color: k.line)),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? k.lagoon : k.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? k.onLagoon : k.inkMuted,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: k.inkMuted, width: 1.5),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: k.mist,
        modalBackgroundColor: k.mist,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: k.line,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(KRadius.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: k.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: KRadius.sheetAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: k.inkMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: k.hero,
        contentTextStyle: text.bodyMedium?.copyWith(color: k.onHero),
        actionTextColor: isDark ? k.brand : const Color(0xFF7FD3D9),
        shape: RoundedRectangleBorder(borderRadius: KRadius.controlAll),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: k.brand,
        linearTrackColor: k.surfaceAlt,
        circularTrackColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: k.line, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: k.inkMuted,
        textColor: k.ink,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(color: k.inkMuted),
        shape: RoundedRectangleBorder(borderRadius: KRadius.cardAll),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: k.brand,
        collapsedIconColor: k.inkMuted,
        textColor: k.ink,
        collapsedTextColor: k.ink,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: k.brand,
        unselectedLabelColor: k.inkMuted,
        indicatorColor: k.brand,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        dividerColor: k.line,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: k.hero,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: text.bodySmall?.copyWith(color: k.onHero),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: k.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: KRadius.cardAll),
        textStyle: text.bodyMedium,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(k.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }

  static TextTheme _textTheme(KoraiColors k) {
    TextStyle display(double size, FontWeight w, {double h = 1.15}) =>
        TextStyle(
          fontFamily: KFonts.display,
          fontSize: size,
          fontWeight: w,
          height: h,
          letterSpacing: -0.2,
          color: k.ink,
        );
    TextStyle body(double size, FontWeight w, {double h = 1.45, Color? c}) =>
        TextStyle(
          fontFamily: KFonts.body,
          fontSize: size,
          fontWeight: w,
          height: h,
          color: c ?? k.ink,
        );

    return TextTheme(
      displayLarge: display(44, FontWeight.w700, h: 1.05),
      displayMedium: display(36, FontWeight.w700, h: 1.08),
      displaySmall: display(30, FontWeight.w700),
      headlineLarge: display(28, FontWeight.w700),
      headlineMedium: display(25, FontWeight.w700),
      headlineSmall: display(21, FontWeight.w600),
      titleLarge: display(18, FontWeight.w600, h: 1.25),
      titleMedium: body(16, FontWeight.w700, h: 1.3),
      titleSmall: body(14.5, FontWeight.w700, h: 1.3),
      bodyLarge: body(16, FontWeight.w400),
      bodyMedium: body(15, FontWeight.w400),
      bodySmall: body(13, FontWeight.w400, c: k.inkMuted),
      labelLarge: body(15, FontWeight.w700, h: 1.2),
      labelMedium: body(13, FontWeight.w600, h: 1.2),
      labelSmall: body(12, FontWeight.w600, h: 1.2),
    );
  }
}
