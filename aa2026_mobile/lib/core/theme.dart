import 'package:flutter/material.dart';

class AppColors {
  static const accent = Color(0xFFF26B1D);
  static const star = Color(0xFFFFB020);
  static const ok = Color(0xFF1FA463);
  static const danger = Color(0xFFE5484D);
  static const info = Color(0xFF3B82F6);
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? const Color(0xFF0E0E10) : const Color(0xFFF1F1F3);
    final surface = dark ? const Color(0xFF1A1A1E) : Colors.white;
    final ink = dark ? const Color(0xFFF5F5F7) : const Color(0xFF111114);
    final scheme = ColorScheme(
      brightness: b,
      primary: ink,
      onPrimary: dark ? const Color(0xFF111114) : Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
    );
    final base = ThemeData(brightness: b, useMaterial3: true);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      dividerColor: dark ? const Color(0xFF2A2A2F) : const Color(0xFFE4E4E8),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: TextStyle(
          color: dark ? const Color(0xFF111114) : Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get ink => Theme.of(this).colorScheme.onSurface;
  Color get onInk => Theme.of(this).colorScheme.onPrimary;
  Color get card => Theme.of(this).colorScheme.surface;
  Color get page => Theme.of(this).scaffoldBackgroundColor;
  Color get muted => isDark ? const Color(0xFF9A9AA2) : const Color(0xFF7C7C85);
  Color get field => isDark ? const Color(0xFF26262B) : const Color(0xFFEBEBEE);
  Color get line => Theme.of(this).dividerColor;
}

BoxDecoration cardDeco(BuildContext context, {double radius = 20}) {
  return BoxDecoration(
    color: context.card,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: context.isDark
        ? null
        : [BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 16, offset: const Offset(0, 4))],
  );
}
