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

  // ── Theme-aware lookups ───────────────────────────────────────────────────
  // Everything below resolves from the *active* Material theme rather than from
  // the constants above. That is what makes a colour change in Settings show up
  // on every page: the brand palette is only the default (see `ColorMode`), and
  // the theme carries whatever the user picked.

  /// Page background.
  static Color backgroundOf(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;

  /// Card / sheet surface colour.
  static Color surfaceOf(BuildContext context) => Theme.of(context).cardColor;

  /// Slightly raised surface (e.g. nested tiles, code blocks).
  static Color surfaceAltOf(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHighest;

  /// Hairline border / divider colour.
  static Color borderOf(BuildContext context) => Theme.of(context).colorScheme.outline;

  /// Primary text colour.
  static Color textMainOf(BuildContext context) => Theme.of(context).colorScheme.onSurface;

  /// Muted / supporting text colour.
  static Color textMutedOf(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;

  /// Semantic colours that follow the active scheme where it defines them and
  /// otherwise fall back to the brand palette for the current brightness.
  static Color successOf(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? success : const Color(0xFF15803D);

  static Color warningOf(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? warning : const Color(0xFFA16207);

  static Color dangerOf(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? danger : const Color(0xFFB91C1C);

  /// The active accent.
  static Color primaryOf(BuildContext context) => Theme.of(context).colorScheme.primary;

  static ThemeData get darkTheme => buildFromScheme(_brandScheme(Brightness.dark));

  static ThemeData get lightTheme => buildFromScheme(_brandScheme(Brightness.light));

  /// The default Doorstep colour scheme for [brightness].
  static ColorScheme _brandScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Choose primary based on brightness to ensure good contrast
    final activePrimary = isDark ? primary : const Color(0xFF0F60FF);
    final activeSecondary = isDark ? accent : const Color(0xFF006874);

    return ColorScheme.fromSeed(
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
      onSurfaceVariant: isDark ? textMuted : const Color(0xFF64748B),
      surfaceContainerHighest: isDark ? surfaceBorder : const Color(0xFFE2E8F0),
      surfaceContainerLowest: isDark ? background : lightBackground,
      inverseSurface: isDark ? const Color(0xFF1E222B) : const Color(0xFF1E293B),
      onInverseSurface: textMain,
      outline: isDark ? surfaceBorder : const Color(0xFFCBD5E1),
    );
  }

  /// Applies the Doorstep component treatment (rounded containment, stadium
  /// controls, tonal surfaces) on top of *any* colour scheme.
  ///
  /// This is what keeps the app's shape language when the user switches colour
  /// mode: the accent changes, the layout and shapes do not.
  static ThemeData buildFromScheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final activePrimary = colorScheme.primary;

    final border = OutlineInputBorder(
      borderSide: BorderSide(color: colorScheme.outline),
      borderRadius: BorderRadius.circular(16),
    );

    return (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      cardColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainerLowest,
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
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outline, width: 0.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
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
          if (states.contains(WidgetState.selected)) return colorScheme.onPrimary;
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return colorScheme.outline;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: activePrimary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: activePrimary.withValues(alpha: 0.18),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: colorScheme.onSurfaceVariant),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: activePrimary.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: activePrimary),
        selectedLabelTextStyle: TextStyle(
          color: activePrimary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
      ),
    );
  }
}
