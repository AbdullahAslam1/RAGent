import 'package:flutter/material.dart';

/// Warm neutral surfaces with a deep teal accent.
/// To change the accent, edit the `primary*` colors in light() and dark().
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF0F766E);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF0F766E),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDDF1EC),
      onPrimaryContainer: const Color(0xFF0B3D38),
      surface: const Color(0xFFFBFAF8),
      onSurface: const Color(0xFF1F1D1A),
      onSurfaceVariant: const Color(0xFF77726A),
      surfaceContainerLow: const Color(0xFFF4F2ED), // sidebar
      surfaceContainer: const Color(0xFFEFEDE7),
      surfaceContainerHigh: const Color(0xFFFFFFFF), // input, cards
      surfaceContainerHighest: const Color(0xFFEAE7E0), // hover / selected
      outline: const Color(0xFFB9B4AA),
      outlineVariant: const Color(0xFFE4E0D8),
      errorContainer: const Color(0xFFFBE4E1),
      onErrorContainer: const Color(0xFF7A1F16),
    );
    return _build(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF4FD1C5),
      onPrimary: const Color(0xFF00302B),
      primaryContainer: const Color(0xFF14463F),
      onPrimaryContainer: const Color(0xFFCDF3EE),
      surface: const Color(0xFF131312),
      onSurface: const Color(0xFFECEAE5),
      onSurfaceVariant: const Color(0xFF9B978E),
      surfaceContainerLow: const Color(0xFF1A1A18),
      surfaceContainer: const Color(0xFF1F1F1D),
      surfaceContainerHigh: const Color(0xFF232321),
      surfaceContainerHighest: const Color(0xFF2D2D2A),
      outline: const Color(0xFF6B6860),
      outlineVariant: const Color(0xFF2E2E2B),
      errorContainer: const Color(0xFF4A1F1B),
      onErrorContainer: const Color(0xFFFFDAD5),
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme s) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: s.brightness,
      colorScheme: s,
    );

    return base.copyWith(
      scaffoldBackgroundColor: s.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: s.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: s.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 500),
      ),
    );
  }
}