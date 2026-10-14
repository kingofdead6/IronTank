import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../data/workout_models.dart';

/// Column widths shared by the header row and every set row.
abstract final class SetColumns {
  static const double badge = AppSizes.minTapTarget * 0.75;
  static const double rpe = AppSizes.minTapTarget;
  static const double check = AppSizes.minTapTarget;
  static const int previousFlex = 3;
  static const int fieldFlex = 2;
}

/// Callbacks a set row reports to its exercise card.
class SetRowActions {
  const SetRowActions({
    required this.onWeight,
    required this.onReps,
    required this.onRpe,
    required this.onCycleType,
    required this.onToggle,
  });

  final ValueChanged<double?> onWeight;
  final ValueChanged<int?> onReps;
  final VoidCallback onRpe;
  final VoidCallback onCycleType;

  /// Returns false when the set can't be completed (no reps anywhere).
  final bool Function() onToggle;
}

/// One logged set: type badge · previous (ghost) · weight · reps · RPE · ✓
class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.index,
    required this.workingNumber,
    required this.set,
    required this.previous,
    required this.unit,
    required this.isBodyweight,
    required this.actions,
  });

  final int index;

  /// 1-based number among non-warm-up sets (what lifters call "set 2").
  final int workingNumber;
  final WorkoutSet set;
  final PreviousSet? previous;
  final WeightUnit unit;
  final bool isBodyweight;
  final SetRowActions actions;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> with SingleTickerProviderStateMixin {
  late final TextEditingController _weight = TextEditingController(text: _weightText(widget.set.weightKg));
  late final TextEditingController _reps = TextEditingController(text: widget.set.reps?.toString() ?? '');
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  /// Shake when the user taps ✓ with nothing to log.
  late final AnimationController _shake = AnimationController(vsync: this, duration: AppMotion.medium);

  String _weightText(double? kg) => kg == null ? '' : Units.formatNumber(Units.fromKg(kg, widget.unit), decimals: 2);

  @override
  void didUpdateWidget(covariant SetRow old) {
    super.didUpdateWidget(old);
    // Sync values changed elsewhere (ghost fill on ✓, unit switch) unless the user is typing.
    if (!_weightFocus.hasFocus) {
      final text = _weightText(widget.set.weightKg);
      if (_weight.text != text) _weight.text = text;
    }
    if (!_repsFocus.hasFocus) {
      final text = widget.set.reps?.toString() ?? '';
      if (_reps.text != text) _reps.text = text;
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onWeight(String text) {
    final v = double.tryParse(text.replaceAll(',', '.'));
    widget.actions.onWeight(v == null ? null : Units.toKg(v, widget.unit));
  }

  void _onReps(String text) => widget.actions.onReps(int.tryParse(text));

  void _toggle() {
    FocusScope.of(context).unfocus();
    if (!widget.actions.onToggle()) {
      Haptics.warning();
      _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.set;
    final done = s.completed;
    final prev = widget.previous;
    final ghostWeight = prev == null ? (widget.isBodyweight ? '+0' : '') : Units.formatNumber(Units.fromKg(prev.weightKg, widget.unit));
    final ghostReps = prev?.reps.toString() ?? '';

    final row = AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: done ? c.success.withValues(alpha: AppOpacity.faint * 1.5) : Colors.transparent,
        borderRadius: AppRadii.smAll,
      ),
      child: Row(
        children: [
          SizedBox(
            width: SetColumns.badge,
            child: _TypeBadge(type: s.type, number: widget.workingNumber, onTap: widget.actions.onCycleType),
          ),
          Expanded(
            flex: SetColumns.previousFlex,
            child: Text(
              prev == null ? '—' : '${Units.formatNumber(Units.fromKg(prev.weightKg, widget.unit))} × ${prev.reps}',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
          ),
          Expanded(
            flex: SetColumns.fieldFlex,
            child: _NumberField(
              controller: _weight,
              focusNode: _weightFocus,
              hint: ghostWeight,
              decimal: true,
              enabled: !done,
              semanticLabel: 'Set ${widget.index + 1} weight in ${widget.unit.label}',
              onChanged: _onWeight,
              onSubmitted: (_) => _repsFocus.requestFocus(),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            flex: SetColumns.fieldFlex,
            child: _NumberField(
              controller: _reps,
              focusNode: _repsFocus,
              hint: ghostReps,
              decimal: false,
              enabled: !done,
              semanticLabel: 'Set ${widget.index + 1} reps',
              onChanged: _onReps,
              onSubmitted: (_) => _toggle(),
            ),
          ),
          SizedBox(
            width: SetColumns.rpe,
            child: TextButton(
              onPressed: widget.actions.onRpe,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size.square(AppSizes.minTapTarget)),
              child: Text(
                s.rpe == null ? 'RPE' : Units.formatNumber(s.rpe!),
                style: s.rpe == null ? context.text.labelSmall : context.numbers.small.copyWith(color: c.accent),
              ),
            ),
          ),
          SizedBox(width: SetColumns.check, child: _CheckButton(done: done, onTap: _toggle)),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // Damped sine (three wiggles): a quick "nope".
        final t = _shake.value;
        final dx = AppSpacing.sm * (1 - t) * math.sin(t * 6 * math.pi);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: row,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.number, required this.onTap});

  final SetType type;
  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (type) {
      SetType.warmup => c.warning,
      SetType.dropset => c.accentEnd,
      SetType.failure => c.danger,
      SetType.working => c.textSecondary,
    };
    return Tooltip(
      message: '${type.label} — tap to change',
      child: PressableScale(
        onTap: onTap,
        semanticLabel: '${type.label} set. Tap to change type.',
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: AppSizes.iconLg,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: type == SetType.working ? c.glassFill : color.withValues(alpha: AppOpacity.subtle),
            borderRadius: AppRadii.smAll,
          ),
          child: Text(
            type == SetType.working ? '$number' : type.short,
            style: context.numbers.small.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.decimal,
    required this.enabled,
    required this.semanticLabel,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool decimal;
  final bool enabled;
  final String semanticLabel;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: semanticLabel,
      textField: true,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal, signed: decimal),
        textInputAction: decimal ? TextInputAction.next : TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(decimal ? RegExp(r'^-?\d{0,4}([.,]\d{0,2})?') : RegExp(r'^\d{0,4}')),
        ],
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
        style: context.numbers.small,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: context.numbers.small.copyWith(color: c.textMuted.withValues(alpha: AppOpacity.muted)),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + AppSpacing.xxs),
          filled: true,
          fillColor: enabled ? c.glassFill : Colors.transparent,
          border: const OutlineInputBorder(borderRadius: AppRadii.smAll, borderSide: BorderSide.none),
          enabledBorder: const OutlineInputBorder(borderRadius: AppRadii.smAll, borderSide: BorderSide.none),
          disabledBorder: const OutlineInputBorder(borderRadius: AppRadii.smAll, borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: AppRadii.smAll, borderSide: BorderSide(color: c.accent)),
        ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Set completed. Tap to undo.' : 'Complete set',
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        haptic: false,
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.overshoot,
            width: AppSizes.iconXl * 0.85,
            height: AppSizes.iconXl * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done ? LinearGradient(colors: [c.success, c.success.withValues(alpha: AppOpacity.muted)]) : null,
              color: done ? null : c.glassFill,
              border: Border.all(color: done ? Colors.transparent : c.glassBorder),
              boxShadow: done ? [BoxShadow(color: c.success.withValues(alpha: AppOpacity.subtle), blurRadius: AppSpacing.md)] : null,
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(
                Icons.check_rounded,
                key: ValueKey(done),
                size: AppSizes.iconMd,
                color: done ? c.onAccent : c.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
