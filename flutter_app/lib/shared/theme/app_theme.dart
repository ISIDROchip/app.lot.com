import 'package:flutter/material.dart';

/// Luxora color palette
class LuxoraColors {
  LuxoraColors._();

  static const background   = Color(0xFF0D0B2B); // deep navy-purple
  static const surface      = Color(0xFF1A1640); // card surface
  static const surfaceAlt   = Color(0xFF231E55); // elevated card
  static const primary      = Color(0xFFC8620A); // golden orange — buttons
  static const primaryLight = Color(0xFFE07820); // hover / lighter orange
  static const accent       = Color(0xFF7ED321); // lime green — numbers / badges
  static const textPrimary  = Color(0xFFFFFFFF);
  static const textSecondary= Color(0xFF9B97C2); // lavender grey
  static const error        = Color(0xFFFF5252);
  static const divider      = Color(0xFF2E2860);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: LuxoraColors.background,
        colorScheme: const ColorScheme.dark(
          primary:          LuxoraColors.primary,
          onPrimary:        LuxoraColors.textPrimary,
          secondary:        LuxoraColors.accent,
          onSecondary:      LuxoraColors.background,
          surface:          LuxoraColors.surface,
          onSurface:        LuxoraColors.textPrimary,
          error:            LuxoraColors.error,
          onError:          LuxoraColors.textPrimary,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge:  TextStyle(color: LuxoraColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          headlineLarge: TextStyle(color: LuxoraColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          headlineMedium:TextStyle(color: LuxoraColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          titleLarge:    TextStyle(color: LuxoraColors.textPrimary, fontWeight: FontWeight.w600),
          titleMedium:   TextStyle(color: LuxoraColors.textPrimary, fontWeight: FontWeight.w600),
          titleSmall:    TextStyle(color: LuxoraColors.textSecondary, fontWeight: FontWeight.w500),
          bodyLarge:     TextStyle(color: LuxoraColors.textPrimary),
          bodyMedium:    TextStyle(color: LuxoraColors.textSecondary),
          bodySmall:     TextStyle(color: LuxoraColors.textSecondary, fontSize: 12),
          labelLarge:    TextStyle(color: LuxoraColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor:  LuxoraColors.background,
          foregroundColor:  LuxoraColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: LuxoraColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
          iconTheme: const IconThemeData(color: LuxoraColors.textPrimary),
        ),
        cardTheme: CardThemeData(
          color: LuxoraColors.surface,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: LuxoraColors.divider, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: LuxoraColors.primary,
            foregroundColor: LuxoraColors.textPrimary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: LuxoraColors.primary,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: LuxoraColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: LuxoraColors.accent,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: LuxoraColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: LuxoraColors.textSecondary),
          hintStyle: const TextStyle(color: LuxoraColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: LuxoraColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: LuxoraColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: LuxoraColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: LuxoraColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: LuxoraColors.error, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: LuxoraColors.surfaceAlt,
          labelStyle: const TextStyle(color: LuxoraColors.textPrimary, fontWeight: FontWeight.w600),
          side: const BorderSide(color: LuxoraColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        dividerTheme: const DividerThemeData(
          color: LuxoraColors.divider,
          thickness: 1,
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: LuxoraColors.surface,
          textColor: LuxoraColors.textPrimary,
          iconColor: LuxoraColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: LuxoraColors.surfaceAlt,
          contentTextStyle: const TextStyle(color: LuxoraColors.textPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: LuxoraColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: LuxoraColors.divider),
            ),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: LuxoraColors.primary,
        ),
        iconTheme: const IconThemeData(color: LuxoraColors.textSecondary),
      );
}
