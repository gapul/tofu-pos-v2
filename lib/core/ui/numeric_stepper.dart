import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// スピンボタン形式の数値増減（仕様書 §9.3）。
///
/// 1タップで1単位ずつ増減。長押しで連続増減（150ms周期、加速付き）。
class NumericStepper extends StatefulWidget {
  const NumericStepper({
    required this.value,
    required this.onChanged,
    super.key,
    this.min = 0,
    this.max = 999999,
    this.step = 1,
    this.suffix,
    this.formatter,
    this.compact = false,
    this.label,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String? suffix;
  final String Function(int)? formatter;
  final bool compact;
  final String? label;

  @override
  State<NumericStepper> createState() => _NumericStepperState();
}

class _NumericStepperState extends State<NumericStepper> {
  Timer? _holdTimer;
  int _holdAccel = 1;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _bump(int delta) {
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

  @override
  Widget build(BuildContext context) {
    final double size = widget.compact ? 44 : TofuTokens.touchMin;
    final String shown =
        widget.formatter?.call(widget.value) ?? widget.value.toString();
    final String text = widget.suffix == null
        ? shown
        : '$shown${widget.suffix}';

    final TextStyle valueStyle = widget.compact
        ? TofuTextStyles.bodyLgBold
        : TofuTextStyles.h3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(widget.label!, style: TofuTextStyles.bodySmBold),
          const SizedBox(height: TofuTokens.space2),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _StepperButton(
              icon: Icons.remove,
              size: size,
              onTap: () => _bump(-1),
              onLongPressStart: () => _startHold(-1),
              onLongPressEnd: _stopHold,
              isLeft: true,
              enabled: widget.value > widget.min,
            ),
            Container(
              constraints: BoxConstraints(minWidth: size + 16, minHeight: size),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: TofuTokens.space3,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: TofuTokens.borderSubtle),
                  bottom: BorderSide(color: TofuTokens.borderSubtle),
                ),
                color: TofuTokens.bgCanvas,
              ),
              child: Text(text, style: valueStyle, textAlign: TextAlign.center),
            ),
            _StepperButton(
              icon: Icons.add,
              size: size,
              onTap: () => _bump(1),
              onLongPressStart: () => _startHold(1),
              onLongPressEnd: _stopHold,
              isLeft: false,
              enabled: widget.value < widget.max,
            ),
          ],
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.isLeft,
    required this.enabled,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final bool isLeft;
  final bool enabled;

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

    return Material(
      color: enabled ? TofuTokens.brandPrimarySubtle : TofuTokens.gray100,
      borderRadius: radius,
      child: GestureDetector(
        onLongPressStart: enabled ? (_) => onLongPressStart() : null,
        onLongPressEnd: enabled ? (_) => onLongPressEnd() : null,
        onLongPressCancel: enabled ? onLongPressEnd : null,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: TofuTokens.borderSubtle),
              borderRadius: radius,
            ),
            child: Icon(
              icon,
              size: size * 0.4,
              color: enabled
                  ? TofuTokens.brandPrimary
                  : TofuTokens.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}
