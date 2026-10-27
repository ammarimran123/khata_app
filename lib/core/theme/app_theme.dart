import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// The design system is flat and hard-edged: square corners, 2px black
/// rules instead of soft shadows, uppercase micro-labels, Archivo at
/// weight 800 for headings. This ThemeData is the single source of truth
/// for that look — feature screens should pull from Theme.of(context)
/// rather than hardcoding colors/styles.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        primary: AppColors.accent,
        onPrimary: Colors.white,
        surface: AppColors.bg,
        onSurface: AppColors.text,
      ),
    );

    final textTheme = GoogleFonts.archivoTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
        .copyWith(
          headlineMedium: GoogleFonts.archivo(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.02 * 28,
            height: 1.1,
            color: AppColors.text,
          ),
          headlineSmall: GoogleFonts.archivo(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.02 * 22,
            color: AppColors.text,
          ),
          titleLarge: GoogleFonts.archivo(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          labelSmall: GoogleFonts.archivo(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.14 * 10,
            color: AppColors.neutral600,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        titleTextStyle: textTheme.headlineSmall,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral100,
        contentPadding: const EdgeInsets.all(11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: AppColors.neutral400, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: AppColors.neutral400, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: AppColors.accent700, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.neutral700, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          textStyle: GoogleFonts.archivo(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.text, width: 2),
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          textStyle: GoogleFonts.archivo(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent700,
          textStyle: GoogleFonts.archivo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: GoogleFonts.archivo(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}
