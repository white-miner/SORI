import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sori_date_picker.dart';
import 'sori_tokens.dart';

/// Global dark theme for SORI (black base + purple accents).
abstract final class AppTheme {
  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: SoriTokens.primary,
      brightness: Brightness.dark,
      primary: SoriTokens.primary,
      surface: SoriTokens.surface,
      onSurface: SoriTokens.textPrimary,
      onPrimary: Colors.white,
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
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: SoriTokens.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: SoriTokens.primary,
        unselectedItemColor: SoriTokens.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: SoriTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoriTokens.radiusLg),
          side: const BorderSide(
            color: SoriTokens.outlinePurple,
            width: SoriTokens.outlineWidth,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SoriTokens.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: SoriTokens.textPrimary),
        bodyMedium: TextStyle(color: SoriTokens.textPrimary),
        bodySmall: TextStyle(color: SoriTokens.textSecondary),
        titleLarge: TextStyle(color: SoriTokens.textPrimary),
        titleMedium: TextStyle(color: SoriTokens.textPrimary),
        titleSmall: TextStyle(color: SoriTokens.textPrimary),
        labelLarge: TextStyle(color: SoriTokens.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SoriTokens.surface,
        hintStyle: const TextStyle(color: SoriTokens.textSecondary),
        labelStyle: const TextStyle(color: SoriTokens.textSecondary),
        prefixIconColor: SoriTokens.textSecondary,
        suffixIconColor: SoriTokens.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.outlinePurple),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.outlinePurple),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.primary, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.border),
        ),
      ),
      dialogTheme: SoriDatePickerTheme.dialogTheme.copyWith(
        backgroundColor: SoriTokens.surface,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SoriTokens.surface,
        modalBackgroundColor: SoriTokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: SoriTokens.surface,
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
        backgroundColor: SoriTokens.surface,
        selectedColor: SoriTokens.primarySoft,
        disabledColor: SoriTokens.border,
        labelStyle: const TextStyle(color: SoriTokens.textPrimary),
        secondaryLabelStyle: const TextStyle(color: SoriTokens.textSecondary),
        side: const BorderSide(color: SoriTokens.outlinePurple),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SoriTokens.border,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: SoriTokens.textSecondary,
        textColor: SoriTokens.textPrimary,
      ),
      datePickerTheme: SoriDatePickerTheme.data,
    );
  }
}
