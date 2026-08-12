import 'package:flutter/material.dart';

/// Single source of truth for the Doorstep brand palette and theming.
///
/// Every Doorstep screen uses these constants instead of hardcoded hex
/// values, and [DoorstepTheme.darkTheme] / [DoorstepTheme.lightTheme] are the
/// app-wide themes wired in via `getTheme` (see `theme.dart`).
class DoorstepTheme {
  // ── Brand Color Palette (Android 12-16 Material You / M3 Tonal) ─────────
  static const Color background = Color(0xFF0B0D11); // Clean deep steel black
  static const Color surface = Color(0xFF15181E); // Tonal surface container
  static const Color surfaceBorder = Color(0xFF22262E); // Soft matching border
  static const Color primary = Color(0xFF7CB7FF); // Pastel ice blue
  static const Color primaryGlow = Color(0x337CB7FF);
  static const Color accent = Color(0xFF98E6D9); // Minty cyan
  static const Color success = Color(0xFF86EFAC); // Pastel green
  static const Color warning = Color(0xFFFDE047); // Soft yellow
  static const Color danger = Color(0xFFFCA5A5); // Soft red
  static const Color textMain = Color(0xFFF1F5F9); // Clean white-grey
  static const Color textMuted = Color(0xFF8A939E); // Muted slate-grey

  // Light-mode surfaces (keeping a clean, professional M3 tonal structure).
  static const Color lightBackground = Color(0xFFF4F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextMain = Color(0xFF1A1D20);

  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Choose primary based on brightness to ensure good contrast
    final activePrimary = isDark ? primary : const Color(0xFF0F60FF);
    final activeSecondary = isDark ? accent : const Color(0xFF006874);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: activePrimary,
          brightness: brightness,
        ).copyWith(
          primary: activePrimary,
          onPrimary: Colors.white,
          secondary: activeSecondary,
          onSecondary: Colors.white,
          error: danger,
          onError: Colors.white,
          surface: isDark ? surface : lightSurface,
          onSurface: isDark ? textMain : lightTextMain,
          surfaceContainerHighest: isDark ? surfaceBorder : const Color(0xFFE2E8F0),
          outline: isDark ? surfaceBorder : const Color(0xFFCBD5E1),
        );

    final border = OutlineInputBorder(
      borderSide: BorderSide(color: colorScheme.outline),
      borderRadius: BorderRadius.circular(16),
    );

    return (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? background : lightBackground,
      cardColor: isDark ? surface : lightSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? background : lightBackground,
        elevation: 0,
        centerTitle: false,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? surface : lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDark ? surfaceBorder : const Color(0xFFE2E8F0), width: 0.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? surface : lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? surface : lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1E222B) : const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: textMain),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surface : const Color(0xFFE2E8F0),
        border: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: activePrimary, width: 1.5)),
        enabledBorder: border,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: activePrimary,
          side: BorderSide(color: activePrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: activePrimary,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? surfaceBorder : const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return isDark ? surfaceBorder : const Color(0xFFCBD5E1);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: activePrimary,
        linearTrackColor: isDark ? surfaceBorder : const Color(0xFFE2E8F0),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? surfaceBorder : const Color(0xFFE2E8F0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? background : lightBackground,
        indicatorColor: activePrimary.withValues(alpha: 0.18),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: isDark ? textMuted : const Color(0xFF475569)),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: isDark ? textMuted : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? background : lightBackground,
        indicatorColor: activePrimary.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: activePrimary),
        selectedLabelTextStyle: TextStyle(
          color: activePrimary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedIconTheme: IconThemeData(
          color: isDark ? textMuted : const Color(0xFF475569),
        ),
        unselectedLabelTextStyle: TextStyle(
          color: isDark ? textMuted : const Color(0xFF475569),
          fontSize: 13,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222B) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: textMain, fontSize: 12),
      ),
    );
  }
}
