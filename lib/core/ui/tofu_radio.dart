import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Atoms/Radio` (ComponentSet `26:22`) を Flutter で再現。
///
/// state 軸:
/// - `unchecked`: bgSurface + borderDefault
/// - `checked`  : bgSurface + borderFocus (brandPrimary) + 中央に primary 円
/// - `disabled` : bgMuted + borderSubtle
///
/// 寸法: 24×24 / radius 12 (= full)。
@immutable
class TofuRadio<T> extends StatelessWidget {
  const TofuRadio({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    super.key,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;

  bool get _selected => value == groupValue;
  bool get _disabled => onChanged == null;

  @override
  Widget build(BuildContext context) {
    final Color border = _disabled
        ? TofuTokens.borderSubtle
        : (_selected ? TofuTokens.brandPrimary : TofuTokens.borderDefault);
    final Color bg = _disabled ? TofuTokens.bgMuted : TofuTokens.bgSurface;

    final Widget circle = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        shape: BoxShape.circle,
      ),
      child: _selected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _disabled ? TofuTokens.textDisabled : TofuTokens.brandPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );

    if (_disabled) return circle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged!(value),
      child: circle,
    );
  }
}
