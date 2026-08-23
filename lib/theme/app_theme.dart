import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sori_date_picker.dart';
import 'sori_tokens.dart';

/// Global dark theme — Content-First neutrals + mint accent (Phase 9).
abstract final class AppTheme {
  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: SoriTokens.primary,
      brightness: Brightness.dark,
      primary: SoriTokens.primary,
      surface: SoriTokens.surface,
      onSurface: SoriTokens.textPrimary,
      onPrimary: const Color(0xFF00140F),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base,
      scaffoldBackgroundColor: SoriTokens.background,
      canvasColor: SoriTokens.background,
      cardColor: SoriTokens.surface,
      dividerColor: SoriTokens.border,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: SoriTokens.textPrimary,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SoriTokens.background,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: SoriTokens.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: SoriTokens.textPrimary,
        unselectedItemColor: SoriTokens.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: SoriTokens.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoriTokens.radiusLg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SoriTokens.primary,
          foregroundColor: const Color(0xFF00140F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SoriTokens.primary;
          }
          return SoriTokens.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SoriTokens.primarySoft;
          }
          return SoriTokens.surfaceOverlay;
        }),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: SoriTokens.textPrimary),
        bodyMedium: TextStyle(color: SoriTokens.textSecondary),
        bodySmall: TextStyle(color: SoriTokens.textTertiary),
        titleLarge: TextStyle(color: SoriTokens.textPrimary),
        titleMedium: TextStyle(color: SoriTokens.textPrimary),
        titleSmall: TextStyle(color: SoriTokens.textSecondary),
        labelLarge: TextStyle(color: SoriTokens.textPrimary),
        labelMedium: TextStyle(color: SoriTokens.textTertiary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SoriTokens.surfaceElevated,
        hintStyle: const TextStyle(color: SoriTokens.textQuaternary),
        labelStyle: const TextStyle(color: SoriTokens.textTertiary),
        prefixIconColor: SoriTokens.textTertiary,
        suffixIconColor: SoriTokens.textTertiary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.primary, width: 1.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      dialogTheme: SoriDatePickerTheme.dialogTheme.copyWith(
        backgroundColor: SoriTokens.surfaceElevated,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SoriTokens.surfaceElevated,
        modalBackgroundColor: SoriTokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: SoriTokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: SoriTokens.textPrimary),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: SoriTokens.surfaceElevated,
        contentTextStyle: TextStyle(color: SoriTokens.textPrimary),
        actionTextColor: SoriTokens.primary,
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SoriTokens.surfaceOverlay,
        selectedColor: SoriTokens.primarySoft,
        disabledColor: SoriTokens.surfaceOverlay,
        labelStyle: const TextStyle(color: SoriTokens.textSecondary),
        secondaryLabelStyle: const TextStyle(color: SoriTokens.textTertiary),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SoriTokens.border,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: SoriTokens.textTertiary,
        textColor: SoriTokens.textPrimary,
      ),
      datePickerTheme: SoriDatePickerTheme.data,
    );
  }
}
