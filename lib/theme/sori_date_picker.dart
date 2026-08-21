import 'dart:ui';

import 'package:flutter/material.dart';

import 'sori_tokens.dart';

/// SORI DatePicker — 다크 서피스 + 퍼플 포인트 공통 테마.
abstract final class SoriDatePickerTheme {
  static const double radius = 24;

  static DatePickerThemeData get data {
    return DatePickerThemeData(
      backgroundColor: SoriTokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(
          color: SoriTokens.outlinePurple,
          width: 1.2,
        ),
      ),
      headerBackgroundColor: SoriTokens.surfaceElevated,
      headerForegroundColor: SoriTokens.textPrimary,
      headerHeadlineStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: SoriTokens.textPrimary,
        letterSpacing: -0.3,
      ),
      headerHelpStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: SoriTokens.textSecondary,
      ),
      weekdayStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: SoriTokens.textSecondary,
      ),
      dayStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: SoriTokens.textPrimary,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        if (states.contains(WidgetState.disabled)) {
          return SoriTokens.textSecondary.withValues(alpha: 0.38);
        }
        return SoriTokens.textPrimary;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return SoriTokens.primary;
        return Colors.transparent;
      }),
      dayOverlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return SoriTokens.primary.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.pressed)) {
          return SoriTokens.primary.withValues(alpha: 0.22);
        }
        return null;
      }),
      dayShape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return SoriTokens.primary;
      }),
      todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return SoriTokens.primary;
        return SoriTokens.primarySoft;
      }),
      todayBorder: const BorderSide(color: SoriTokens.primary, width: 1.4),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        if (states.contains(WidgetState.disabled)) {
          return SoriTokens.textSecondary.withValues(alpha: 0.38);
        }
        return SoriTokens.textPrimary;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return SoriTokens.primary;
        return Colors.transparent;
      }),
      rangePickerBackgroundColor: SoriTokens.surface,
      rangePickerHeaderBackgroundColor: SoriTokens.surfaceElevated,
      dividerColor: SoriTokens.border,
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: SoriTokens.textSecondary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: SoriTokens.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }

  static DialogThemeData get dialogTheme => DialogThemeData(
        backgroundColor: SoriTokens.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  /// [showDatePicker] 공통 호출 — 다크 테마 강제.
  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    Locale? locale,
    String? helpText,
    String? cancelText,
    String? confirmText,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: locale ?? const Locale('ko', 'KR'),
      helpText: helpText ?? '날짜 선택',
      cancelText: cancelText ?? '취소',
      confirmText: confirmText ?? '확인',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context, child) => wrapPicker(context, child),
    );
  }

  static Widget wrapPicker(BuildContext context, Widget? child) {
    final dark = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: SoriTokens.primary,
        onPrimary: Colors.white,
        surface: SoriTokens.surface,
        onSurface: SoriTokens.textPrimary,
      ),
      dialogTheme: dialogTheme,
      datePickerTheme: data,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: SoriTokens.primary),
      ),
    );
    return Theme(
      data: dark,
      child: child ?? const SizedBox.shrink(),
    );
  }
}

/// 커스텀 캘린더/시트용 다크 글래스 서피스.
class SoriGlassPanel extends StatelessWidget {
  const SoriGlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.clipTopOnly = false,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool clipTopOnly;

  @override
  Widget build(BuildContext context) {
    final radius = clipTopOnly
        ? BorderRadius.vertical(top: Radius.circular(borderRadius))
        : BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SoriTokens.surface.withValues(alpha: 0.96),
            borderRadius: radius,
            border: Border.all(color: SoriTokens.outlinePurple, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}
