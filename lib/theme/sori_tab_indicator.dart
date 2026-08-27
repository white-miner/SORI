import 'package:flutter/material.dart';

import 'sori_tokens.dart';

/// YouTube-style gray capsule — pass directly to [TabBar.indicator].
const BoxDecoration soriTabCapsuleIndicator = BoxDecoration(
  borderRadius: BorderRadius.all(Radius.circular(20)),
  color: Color(0xFFF1F1F1),
);

/// Shared TabBar — capsule chip + charcoal labels, no underline.
TabBarThemeData get soriTabBarTheme => const TabBarThemeData(
      overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      labelColor: SoriTokens.textCharcoal,
      unselectedLabelColor: SoriTokens.tabUnselected,
      indicator: soriTabCapsuleIndicator,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      dividerHeight: 0,
      labelStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      labelPadding: EdgeInsets.symmetric(horizontal: 14),
    );
