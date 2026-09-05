import 'package:flutter/material.dart';

/// 탭 순간 1.3배로 커졌다가 제자리로 돌아오는 전역 피드백.
class PressBounce extends StatefulWidget {
  const PressBounce({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 1.3,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressBounce> createState() => _PressBounceState();
}

class _PressBounceState extends State<PressBounce> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: Duration(milliseconds: _pressed ? 70 : 160),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
