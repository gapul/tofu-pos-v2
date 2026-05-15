import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Figma `Molecules/Inputs/NumStepper` (id `31:4`) を Flutter で再現。
///
/// `[-] [value] [+]` の 3 ピース。POS 用途で 56dp 以上のタップターゲットを
/// 確保し、長押しで連続増減 (130ms 周期 + 加速) する。
///
/// 既存 `NumericStepper` の上位互換 (同 API + size/compact 拡張)。
enum TofuNumStepperSize {
  /// 44dp 高 / 中央テキスト bodyLgBold。狭い行 (テーブル列等)。
  sm,

  /// 56dp 高 / 中央テキスト h3。標準。
  md,

  /// 72dp 高 / 中央テキスト numberMd。主要操作 (金種行など)。
  lg,
}

@immutable
class TofuNumStepper extends StatefulWidget {
  const TofuNumStepper({
    required this.value,
    required this.onChanged,
    super.key,
    this.min = 0,
    this.max = 999999,
    this.step = 1,
    this.size = TofuNumStepperSize.md,
    this.suffix,
    this.formatter,
    this.label,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final TofuNumStepperSize size;
  final String? suffix;
  final String Function(int)? formatter;
  final String? label;
  final bool enabled;

  @override
  State<TofuNumStepper> createState() => _TofuNumStepperState();
}

class _TofuNumStepperState extends State<TofuNumStepper> {
  Timer? _holdTimer;
  int _holdAccel = 1;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _bump(int delta) {
    if (!widget.enabled) {
      return;
    }
    final int next = (widget.value + delta * widget.step).clamp(
      widget.min,
      widget.max,
    );
    if (next == widget.value) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    widget.onChanged(next);
  }

  void _startHold(int direction) {
    if (!widget.enabled) {
      return;
    }
    _holdAccel = 1;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 130), (t) {
      if (t.tick > 12 && _holdAccel < 5) {
        _holdAccel = 5;
      } else if (t.tick > 6 && _holdAccel < 2) {
        _holdAccel = 2;
      }
      _bump(direction * _holdAccel);
    });
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  ({double height, TextStyle valueStyle, double iconSize, double minTextWidth})
  _metrics() {
    switch (widget.size) {
      case TofuNumStepperSize.sm:
        return (
          height: 44,
          valueStyle: TofuTextStyles.bodyLgBold,
          iconSize: 20,
          minTextWidth: 56,
        );
      case TofuNumStepperSize.md:
        return (
          height: TofuTokens.touchMin,
          valueStyle: TofuTextStyles.h3,
          iconSize: 24,
          minTextWidth: 72,
        );
      case TofuNumStepperSize.lg:
        return (
          height: TofuTokens.touchPrimary,
          valueStyle: TofuTextStyles.numberMd,
          iconSize: 28,
          minTextWidth: 96,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ({
      double height,
      TextStyle valueStyle,
      double iconSize,
      double minTextWidth,
    })
    m = _metrics();
    final String shown =
        widget.formatter?.call(widget.value) ?? widget.value.toString();
    final String text = widget.suffix == null
        ? shown
        : '$shown${widget.suffix}';
    final bool canDec = widget.enabled && widget.value > widget.min;
    final bool canInc = widget.enabled && widget.value < widget.max;

    final Widget stepper = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepBtn(
          icon: Icons.remove_rounded,
          height: m.height,
          iconSize: m.iconSize,
          isLeft: true,
          enabled: canDec,
          onTap: () => _bump(-1),
          onLongPressStart: () => _startHold(-1),
          onLongPressEnd: _stopHold,
        ),
        Container(
          height: m.height,
          constraints: BoxConstraints(minWidth: m.minTextWidth),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: TofuTokens.space4),
          decoration: const BoxDecoration(
            color: TofuTokens.bgCanvas,
            border: Border(
              top: BorderSide(color: TofuTokens.borderSubtle),
              bottom: BorderSide(color: TofuTokens.borderSubtle),
            ),
          ),
          child: Text(
            text,
            style: m.valueStyle.copyWith(
              color: widget.enabled
                  ? TofuTokens.textPrimary
                  : TofuTokens.textDisabled,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        _StepBtn(
          icon: Icons.add_rounded,
          height: m.height,
          iconSize: m.iconSize,
          isLeft: false,
          enabled: canInc,
          onTap: () => _bump(1),
          onLongPressStart: () => _startHold(1),
          onLongPressEnd: _stopHold,
        ),
      ],
    );

    if (widget.label == null) {
      return stepper;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.label!,
          style: TofuTextStyles.bodySmBold.copyWith(
            color: widget.enabled
                ? TofuTokens.textSecondary
                : TofuTokens.textDisabled,
          ),
        ),
        const SizedBox(height: TofuTokens.space2),
        stepper,
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    required this.icon,
    required this.height,
    required this.iconSize,
    required this.isLeft,
    required this.enabled,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final IconData icon;
  final double height;
  final double iconSize;
  final bool isLeft;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = isLeft
        ? const BorderRadius.only(
            topLeft: Radius.circular(TofuTokens.radiusMd),
            bottomLeft: Radius.circular(TofuTokens.radiusMd),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(TofuTokens.radiusMd),
            bottomRight: Radius.circular(TofuTokens.radiusMd),
          );
    final Color bg = enabled
        ? TofuTokens.brandPrimarySubtle
        : TofuTokens.bgMuted;
    final Color fg = enabled
        ? TofuTokens.brandPrimary
        : TofuTokens.textDisabled;
    return Material(
      color: bg,
      borderRadius: radius,
      child: GestureDetector(
        onLongPressStart: enabled ? (_) => onLongPressStart() : null,
        onLongPressEnd: enabled ? (_) => onLongPressEnd() : null,
        onLongPressCancel: enabled ? onLongPressEnd : null,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Container(
            width: height,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(color: TofuTokens.borderSubtle),
              borderRadius: radius,
            ),
            child: Icon(icon, size: iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}
