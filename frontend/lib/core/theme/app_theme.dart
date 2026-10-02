import 'package:flutter/material.dart';

import '../design/korai_theme.dart';

/// Point d'entrée historique du thème : délègue au thème unique Korai.
class AppTheme {
  static ThemeData light() => KoraiTheme.light();
  static ThemeData dark() => KoraiTheme.dark();
}
