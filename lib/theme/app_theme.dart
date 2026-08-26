import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sori_date_picker.dart';
import 'sori_tab_indicator.dart';
import 'sori_tokens.dart';

/// Global light monochrome theme — off-white canvas + charcoal primary.
abstract final class AppTheme {
  static ThemeData get theme {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: SoriTokens.primary,
      onPrimary: SoriTokens.onPrimary,
      secondary: SoriTokens.primaryLight,
      onSecondary: SoriTokens.onPrimary,
      surface: SoriTokens.surface,
      onSurface: SoriTokens.textPrimary,
      error: SoriTokens.systemRed,
      onError: SoriTokens.onPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      primaryColor: SoriTokens.primary,
      scaffoldBackgroundColor: SoriTokens.background,
      canvasColor: SoriTokens.background,
      cardColor: SoriTokens.surface,
      dividerColor: SoriTokens.border,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      tabBarTheme: soriTabBarTheme,
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
        systemOverlayStyle: SystemUiOverlayStyle.dark,
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
          side: const BorderSide(color: SoriTokens.border, width: SoriTokens.outlineWidth),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SoriTokens.primary,
          foregroundColor: SoriTokens.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SoriTokens.primary,
          foregroundColor: SoriTokens.onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SoriTokens.textPrimary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: SoriTokens.glassFill,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SoriTokens.onPrimary;
          }
          return SoriTokens.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SoriTokens.primary;
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
        fillColor: SoriTokens.surface,
        hintStyle: const TextStyle(color: SoriTokens.textQuaternary),
        labelStyle: const TextStyle(color: SoriTokens.textTertiary),
        prefixIconColor: SoriTokens.textTertiary,
        suffixIconColor: SoriTokens.textTertiary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.border, width: SoriTokens.outlineWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.border, width: SoriTokens.outlineWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.primary, width: 1.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: SoriTokens.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SoriTokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        titleTextStyle: const TextStyle(
          color: SoriTokens.textCharcoal,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: SoriTokens.textCharcoal,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoriTokens.radiusXl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: SoriTokens.glassFill,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(color: SoriTokens.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoriTokens.radiusMd),
          side: const BorderSide(color: SoriTokens.border, width: SoriTokens.outlineWidth),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: SoriTokens.primary,
        contentTextStyle: TextStyle(color: SoriTokens.onPrimary),
        actionTextColor: SoriTokens.onPrimary,
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
      badgeTheme: const BadgeThemeData(
        backgroundColor: SoriTokens.systemRed,
        textColor: SoriTokens.onPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SoriTokens.primary,
      ),
    );
  }

  /// @deprecated Use [theme]
  static ThemeData get dark => theme;
}
