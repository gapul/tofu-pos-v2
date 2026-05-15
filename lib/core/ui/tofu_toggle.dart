import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Atoms/Toggle` (ComponentSet `26:10`) を Flutter で再現したスイッチ。
///
/// state 軸:
/// - `off-default` : track=bgMuted, knob=bgSurface (left)
/// - `on-default`  : track=brandPrimary, knob=bgSurface (right)
/// - `off-disabled`: track=bgMuted, 透明度低下
/// - `on-disabled` : track=brandPrimary, 透明度低下
///
/// 寸法: track 56×32 / radius 16, knob 24×24 (4px inset)。
@immutable
class TofuToggle extends StatelessWidget {
  const TofuToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  bool get _disabled => onChanged == null;

  @override
  Widget build(BuildContext context) {
    final Color trackColor = value ? TofuTokens.brandPrimary : TofuTokens.bgMuted;
    final Widget body = Opacity(
      opacity: _disabled ? 0.5 : 1.0,
      child: AnimatedContainer(
        duration: TofuTokens.motionShort,
        curve: Curves.easeOut,
        width: 56,
        height: 32,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: TofuTokens.bgSurface,
              shape: BoxShape.circle,
              boxShadow: TofuTokens.elevationSm,
            ),
          ),
        ),
      ),
    );

    if (_disabled) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged!(!value),
      child: body,
    );
  }
}
