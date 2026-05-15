import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Figma `Molecules/Inputs/NumStepper` (id `31:4`) を Flutter で再現。
///
/// `[-] [value] [+]` の 3 ピース。POS 用途で 56dp 以上のタップターゲットを
/// 確保し、長押しで連続増減 (130ms 周期 + 加速) する。
///
/// 中央数値表示はタップで TextField モードに切り替わり、物理キーボードから
/// 直接入力できる。Enter / Tab / フォーカス外で確定、ESC で取り消し。
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

  bool _isEditing = false;
  late final TextEditingController _textCtrl = TextEditingController();
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _commit();
    }
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

  void _beginEdit() {
    if (!widget.enabled || _isEditing) {
      return;
    }
    _textCtrl.text = widget.value.toString();
    _textCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textCtrl.text.length,
    );
    setState(() => _isEditing = true);
    // フォーカス確定は次フレームで（AnimatedSwitcher の build を待つ）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _commit() {
    if (!_isEditing) {
      return;
    }
    final String raw = _textCtrl.text.trim();
    int? parsed = int.tryParse(raw);
    if (parsed == null) {
      // 不正値は破棄、現在値に戻すだけ。
      setState(() => _isEditing = false);
      return;
    }
    parsed = parsed.clamp(widget.min, widget.max);
    setState(() => _isEditing = false);
    if (parsed != widget.value) {
      unawaited(HapticFeedback.selectionClick());
      widget.onChanged(parsed);
    }
  }

  void _cancel() {
    setState(() => _isEditing = false);
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
    final bool signed = widget.min < 0;

    final Color valueColor = widget.enabled
        ? TofuTokens.textPrimary
        : TofuTokens.textDisabled;

    final Widget centerChild = _isEditing
        ? _buildEditor(
            key: const ValueKey<String>('edit'),
            metrics: m,
            valueColor: valueColor,
            signed: signed,
          )
        : _buildDisplay(
            key: const ValueKey<String>('view'),
            metrics: m,
            text: text,
            valueColor: valueColor,
          );

    final Widget stepper = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepBtn(
          icon: Icons.remove_rounded,
          height: m.height,
          iconSize: m.iconSize,
          isLeft: true,
          enabled: canDec && !_isEditing,
          onTap: () => _bump(-1),
          onLongPressStart: () => _startHold(-1),
          onLongPressEnd: _stopHold,
        ),
        Container(
          height: m.height,
          constraints: BoxConstraints(minWidth: m.minTextWidth),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: TofuTokens.bgCanvas,
            border: Border(
              top: BorderSide(color: TofuTokens.borderSubtle),
              bottom: BorderSide(color: TofuTokens.borderSubtle),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: centerChild,
          ),
        ),
        _StepBtn(
          icon: Icons.add_rounded,
          height: m.height,
          iconSize: m.iconSize,
          isLeft: false,
          enabled: canInc && !_isEditing,
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

  Widget _buildDisplay({
    required Key key,
    required ({
      double height,
      TextStyle valueStyle,
      double iconSize,
      double minTextWidth,
    })
    metrics,
    required String text,
    required Color valueColor,
  }) {
    return InkWell(
      key: key,
      onTap: widget.enabled ? _beginEdit : null,
      child: Container(
        height: metrics.height,
        constraints: BoxConstraints(minWidth: metrics.minTextWidth),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: TofuTokens.space4),
        child: Text(
          text,
          style: metrics.valueStyle.copyWith(color: valueColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEditor({
    required Key key,
    required ({
      double height,
      TextStyle valueStyle,
      double iconSize,
      double minTextWidth,
    })
    metrics,
    required Color valueColor,
    required bool signed,
  }) {
    final List<TextInputFormatter> formatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(
        signed ? RegExp(r'^-?\d*') : RegExp(r'\d*'),
      ),
    ];
    return SizedBox(
      key: key,
      height: metrics.height,
      width: metrics.minTextWidth + 24,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _CancelIntent: CallbackAction<_CancelIntent>(
              onInvoke: (_) {
                _cancel();
                return null;
              },
            ),
          },
          child: TextField(
            controller: _textCtrl,
            focusNode: _focusNode,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(signed: signed),
            inputFormatters: formatters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _commit(),
            onEditingComplete: _commit,
            style: metrics.valueStyle.copyWith(color: valueColor),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: TofuTokens.space2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelIntent extends Intent {
  const _CancelIntent();
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
