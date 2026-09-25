import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sori_date_picker.dart';
import 'sori_glass_theme.dart';
import 'sori_tab_indicator.dart';
import 'sori_tokens.dart';

/// Global light monochrome theme — warm-white canvas ([SoriTokens.canvas])
/// + charcoal primary + no-blur glass controls ([SoriGlassTheme]).
abstract final class AppTheme {
  /// 시안 본문. 한글은 Noto Sans KR로 폴백한다.
  static final String sansFamily = GoogleFonts.workSans().fontFamily!;
  static final String sansKrFamily = GoogleFonts.notoSansKr().fontFamily!;

  /// 시안 제목. 한글은 Noto Serif KR로 폴백한다.
  static final String displayFamily = GoogleFonts.instrumentSerif().fontFamily!;
  static final String displayKrFamily = GoogleFonts.notoSerifKr().fontFamily!;

  static List<String> get sansFallback => [sansKrFamily];
  static List<String> get displayFallback => [displayKrFamily, sansKrFamily];

  static TextStyle display({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
  }) {
    return GoogleFonts.instrumentSerif(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    ).copyWith(fontFamilyFallback: displayFallback);
  }

  static ThemeData get theme {
    const glass = SoriGlassTheme.standard;
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
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      colorScheme: scheme,
      primaryColor: SoriTokens.primary,
      scaffoldBackgroundColor: SoriTokens.canvas,
      canvasColor: SoriTokens.canvas,
      extensions: const <ThemeExtension<dynamic>>[glass],
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
        backgroundColor: SoriTokens.canvas,
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
          disabledForegroundColor: SoriTokens.onPrimary.withValues(alpha: 0.55),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: SoriTokens.onPrimary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SoriTokens.primary,
          foregroundColor: SoriTokens.onPrimary,
          disabledForegroundColor: SoriTokens.onPrimary.withValues(alpha: 0.55),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: SoriTokens.onPrimary,
          ),
        ),
      ),
      // Glass look without blur: translucent white + hairline + top sheen
      // (backgroundBuilder, clipped to the shape) + soft shadow.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return glass.fillDisabled;
            }
            if (states.contains(WidgetState.pressed)) return glass.fillPressed;
            return glass.fill;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return SoriTokens.textTertiary;
            }
            return glass.foreground;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return SoriTokens.textTertiary;
            }
            return glass.foreground;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return glass.pressOverlay;
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: glass.border.withValues(alpha: 0.05));
            }
            return BorderSide(color: glass.border);
          }),
          // Constant per state: no shadow animation on press.
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return 0;
            return glass.elevation;
          }),
          shadowColor: WidgetStatePropertyAll<Color>(glass.shadowColor),
          surfaceTintColor:
              const WidgetStatePropertyAll<Color>(Colors.transparent),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(glass.radius),
            ),
          ),
          // No textStyle override: keep the theme's labelLarge (Work Sans +
          // Korean fallback) so labels don't drop to the engine default font.
          backgroundBuilder: glass.highlightBackground,
        ),
      ),
      // Text buttons stay flat — only a light glass-tinted press overlay.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SoriTokens.textPrimary,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return glass.pressOverlay;
            return Colors.transparent;
          }),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: glass.fill,
        foregroundColor: glass.foreground,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 2,
        disabledElevation: 0,
        shape: StadiumBorder(side: BorderSide(color: glass.border)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SoriTokens.onPrimary;
          }
          return SoriTokens.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SoriTokens.primary;
          }
          return SoriTokens.chipIdleBg;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return SoriTokens.inputBorder;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return SoriTokens.primary;
            }
            return glass.fill;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return SoriTokens.onPrimary;
            }
            return SoriTokens.tabUnselected;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return SoriTokens.onPrimary;
            }
            return SoriTokens.tabUnselected;
          }),
          textStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected
                  ? SoriTokens.onPrimary
                  : SoriTokens.tabUnselected,
            );
          }),
          side: WidgetStatePropertyAll(BorderSide(color: glass.border)),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: display(color: SoriTokens.textPrimary),
        displayMedium: display(color: SoriTokens.textPrimary),
        displaySmall: display(color: SoriTokens.textPrimary),
        headlineLarge: display(color: SoriTokens.textPrimary),
        headlineMedium: display(color: SoriTokens.textPrimary),
        headlineSmall: display(color: SoriTokens.textPrimary),
        titleLarge: GoogleFonts.workSans(color: SoriTokens.textPrimary),
        titleMedium: GoogleFonts.workSans(color: SoriTokens.textPrimary),
        titleSmall: GoogleFonts.workSans(color: SoriTokens.textSecondary),
        bodyLarge: GoogleFonts.workSans(color: SoriTokens.textPrimary),
        bodyMedium: GoogleFonts.workSans(color: SoriTokens.textSecondary),
        bodySmall: GoogleFonts.workSans(color: SoriTokens.textTertiary),
        labelLarge: GoogleFonts.workSans(color: SoriTokens.textPrimary),
        labelMedium: GoogleFonts.workSans(color: SoriTokens.textTertiary),
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
          borderSide: const BorderSide(
            color: SoriTokens.inputBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: SoriTokens.inputBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.primary, width: 1.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoriTokens.inputBorder),
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
        // Idle = translucent white glass + hairline; selected stays charcoal.
        backgroundColor: glass.fill,
        selectedColor: SoriTokens.primary,
        disabledColor: glass.fillDisabled,
        checkmarkColor: SoriTokens.onPrimary,
        deleteIconColor: SoriTokens.tabUnselected,
        labelStyle: const TextStyle(
          color: SoriTokens.tabUnselected,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: SoriTokens.onPrimary,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return BorderSide.none;
          return BorderSide(color: glass.border);
        }),
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
        textColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SoriTokens.primary,
      ),
    );
  }

  /// @deprecated Use [theme]
  static ThemeData get dark => theme;
}
