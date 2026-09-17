import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../operation/models/shop_climate_context.dart';
import '../../../widgets/press_bounce.dart';
import '../home_dashboard_controller.dart';
import '../home_visual_tokens.dart';

class HomeToolboxRow extends StatelessWidget {
  const HomeToolboxRow({
    super.key,
    required this.controller,
    required this.careRunning,
    required this.climate,
    required this.onTimerTap,
    required this.onWeatherTap,
  });

  final HomeDashboardController controller;
  final bool careRunning;
  final ShopClimateContext? climate;
  final VoidCallback onTimerTap;
  final VoidCallback onWeatherTap;

  @override
  Widget build(BuildContext context) {
    final c = climate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeVisualTokens.heroCardPaddingH,
        0,
        HomeVisualTokens.heroCardPaddingH,
        12,
      ),
      child: Material(
        color: HomeVisualTokens.heroCardFill,
        borderRadius: BorderRadius.circular(HomeVisualTokens.toolboxCardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: HomeVisualTokens.toolboxPaddingV,
            horizontal: HomeVisualTokens.toolboxPaddingH,
          ),
          child: Row(
            children: [
              Expanded(
                child: _ToolIcon(
                  icon: Icons.timer_outlined,
                  label: '타이머',
                  active: controller.activeTool == HomeToolboxTool.timer ||
                      careRunning,
                  ringColor: HomeVisualTokens.careGreen,
                  onTap: onTimerTap,
                ),
              ),
              Expanded(
                child: _ToolIcon(
                  icon: Icons.hourglass_bottom_rounded,
                  label: '카운트',
                  active: controller.activeTool == HomeToolboxTool.count,
                  ringColor: const Color(0xFFFF9500),
                  onTap: controller.toggleCountTool,
                ),
              ),
              Expanded(
                child: _ToolIcon(
                  icon: Icons.calculate_outlined,
                  label: '계산기',
                  active: controller.calculatorOpen,
                  ringColor: const Color(0xFF007AFF),
                  onTap: controller.toggleCalculator,
                ),
              ),
              Expanded(
                child: _ToolIcon(
                  icon: Icons.wb_cloudy_outlined,
                  label: c?.weatherLabelKo ?? '조금 흐림',
                  active: false,
                  onTap: onWeatherTap,
                ),
              ),
              Expanded(
                child: _ToolIcon(
                  icon: Icons.thermostat_outlined,
                  label: c != null ? '${c.tempC.round()}°C' : '--',
                  active: false,
                  onTap: onWeatherTap,
                ),
              ),
              Expanded(
                child: _ToolIcon(
                  icon: Icons.wb_sunny_outlined,
                  label: c != null ? 'UV ${c.uvIndex.round()}' : 'UV',
                  active: false,
                  onTap: onWeatherTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.ringColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: active
                    ? Border.all(color: ringColor ?? Colors.black, width: 2)
                    : null,
              ),
              child: Icon(
                icon,
                size: HomeVisualTokens.toolboxIconSize,
                color: HomeVisualTokens.toolboxIconColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: HomeVisualTokens.toolboxLabelSize,
                fontWeight: FontWeight.w700,
                color: HomeVisualTokens.toolboxLabelColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
