import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Couleurs du thème "Dashboard Pro"
class AppColors {
  // Fonds
  static const background = Color(0xFF071019);
  static const surface = Color(0xFF0E1A25);
  static const surfaceLight = Color(0xFF152534);
  static const cardBorder = Color(0xFF22394A);

  // Accents
  static const accent = Color(0xFF54E1C1);
  static const accentGreen = Color(0xFF54E1A1);
  static const accentOrange = Color(0xFFFFB454);
  static const accentRed = Color(0xFFFF6B6B);
  static const accentPurple = Color(0xFFA98BFF);
  static const accentCyan = Color(0xFF62C7FF);

  // Texte
  static const textPrimary = Color(0xFFF3F8FB);
  static const textSecondary = Color(0xFFA8BAC8);
  static const textMuted = Color(0xFF667C8D);

  // Gradients
  static const gradientStart = Color(0xFF137F8A);
  static const gradientEnd = Color(0xFF54E1C1);

  // Risk badges
  static Color riskColor(String level) {
    switch (level) {
      case 'green':
        return accentGreen;
      case 'orange':
        return accentOrange;
      case 'red':
        return accentRed;
      default:
        return textSecondary;
    }
  }
}

class AppLightColors {
  static const background = Color(0xFFF4F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFEAF0F3);
  static const cardBorder = Color(0xFFD5E0E5);
  static const accent = Color(0xFF087A70);
  static const accentGreen = Color(0xFF147D53);
  static const accentOrange = Color(0xFF9B5A00);
  static const accentRed = Color(0xFFB4232D);
  static const accentPurple = Color(0xFF6246B4);
  static const accentCyan = Color(0xFF006A91);
  static const textPrimary = Color(0xFF101C24);
  static const textSecondary = Color(0xFF465B68);
  static const textMuted = Color(0xFF70838E);
  static const gradientStart = Color(0xFFC8F2EA);
  static const gradientEnd = Color(0xFF8CDED0);
}

class AdaptiveAppColors {
  final Brightness brightness;

  const AdaptiveAppColors(this.brightness);

  bool get _dark => brightness == Brightness.dark;
  Color get background => _dark ? AppColors.background : AppLightColors.background;
  Color get surface => _dark ? AppColors.surface : AppLightColors.surface;
  Color get surfaceLight =>
      _dark ? AppColors.surfaceLight : AppLightColors.surfaceLight;
  Color get cardBorder =>
      _dark ? AppColors.cardBorder : AppLightColors.cardBorder;
  Color get accent => _dark ? AppColors.accent : AppLightColors.accent;
  Color get accentGreen =>
      _dark ? AppColors.accentGreen : AppLightColors.accentGreen;
  Color get accentOrange =>
      _dark ? AppColors.accentOrange : AppLightColors.accentOrange;
  Color get accentRed => _dark ? AppColors.accentRed : AppLightColors.accentRed;
  Color get accentPurple =>
      _dark ? AppColors.accentPurple : AppLightColors.accentPurple;
  Color get accentCyan =>
      _dark ? AppColors.accentCyan : AppLightColors.accentCyan;
  Color get textPrimary =>
      _dark ? AppColors.textPrimary : AppLightColors.textPrimary;
  Color get textSecondary =>
      _dark ? AppColors.textSecondary : AppLightColors.textSecondary;
  Color get textMuted => _dark ? AppColors.textMuted : AppLightColors.textMuted;
  Color get gradientStart =>
      _dark ? AppColors.gradientStart : AppLightColors.gradientStart;
  Color get gradientEnd =>
      _dark ? AppColors.gradientEnd : AppLightColors.gradientEnd;

  Color riskColor(String level) {
    return switch (level) {
      'green' => accentGreen,
      'orange' => accentOrange,
      'red' => accentRed,
      _ => textSecondary,
    };
  }
}

extension AppThemeContext on BuildContext {
  AdaptiveAppColors get appColors =>
      AdaptiveAppColors(Theme.of(this).brightness);
}

class AppTheme {
  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      background: AppLightColors.background,
      surface: AppLightColors.surface,
      surfaceLight: AppLightColors.surfaceLight,
      border: AppLightColors.cardBorder,
      primary: AppLightColors.accent,
      secondary: AppLightColors.accentCyan,
      error: AppLightColors.accentRed,
      textPrimary: AppLightColors.textPrimary,
      textSecondary: AppLightColors.textSecondary,
      textMuted: AppLightColors.textMuted,
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      background: AppColors.background,
      surface: AppColors.surface,
      surfaceLight: AppColors.surfaceLight,
      border: AppColors.cardBorder,
      primary: AppColors.accent,
      secondary: AppColors.accentCyan,
      error: AppColors.accentRed,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textMuted: AppColors.textMuted,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceLight,
    required Color border,
    required Color primary,
    required Color secondary,
    required Color error,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textMuted),
        prefixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: brightness == Brightness.dark
              ? AppColors.background
              : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: brightness == Brightness.dark
            ? AppColors.background
            : Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: .16),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? primary
                : textSecondary,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: border,
    );
  }
}
