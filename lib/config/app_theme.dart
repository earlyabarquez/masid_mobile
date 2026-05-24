import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Sora',
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,

      // ── Color Scheme ──
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        outline: AppColors.border,
      ),

      // ── App Bar ──
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.heading,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.heading,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // ── Bottom Nav ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.label,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── Elevated Button (Primary) ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Sora',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.label,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Chips (for filter pills) ──
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primaryLight,
        labelStyle: const TextStyle(
          fontFamily: 'Sora',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.heading,
        contentTextStyle: const TextStyle(
          fontFamily: 'Sora',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.border,
      ),

      // ── Text Theme ──
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Sora',
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.heading,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Sora',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.heading,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Sora',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.heading,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Sora',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.heading,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Sora',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.body,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Sora',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.secondary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Sora',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.body,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Sora',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.body,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Sora',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.muted,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Sora',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Sora',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.label,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
