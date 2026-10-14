import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/motion.dart';
import '../utils/haptics.dart';

/// Wraps any child with "squish on press, spring back on release" physics.
///
/// Press-in is a quick tween; release is driven by a spring simulation so the
/// surface overshoots slightly, like a physical button.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.haptic = true,
    this.scale = AppMotion.pressScale,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool haptic;
  final double scale;

  /// Announced by screen readers; defaults to the child's own semantics.
  final String? semanticLabel;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> with SingleTickerProviderStateMixin {
  // Value 1 = resting, [widget.scale] = fully pressed. Unbounded so the spring can overshoot.
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 1);

  bool get _active => widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _down(TapDownDetails _) {
    if (!_active) return;
    _c.animateTo(widget.scale, duration: AppMotion.instant, curve: AppMotion.standard);
  }

  void _release() {
    if (!_active) return;
    _c.animateWith(SpringSimulation(AppMotion.pressSpring, _c.value, 1, _c.velocity));
  }

  void _tap() {
    if (!_active) return;
    if (widget.haptic) Haptics.tap();
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: _active,
      enabled: _active,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: widget.onTap == null ? null : _tap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _release();
                if (widget.haptic) Haptics.tap();
                widget.onLongPress!();
              },
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.scale(scale: _c.value, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}
