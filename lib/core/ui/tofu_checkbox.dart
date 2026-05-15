import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Atoms/Checkbox` (ComponentSet `26:17`) を Flutter で再現。
///
/// state 軸（Figma 名 → 解釈）:
/// - `unchecked`           : value=false, enabled
/// - `checked`             : value=true,  enabled
/// - `disabled-unchecked`  : value=false, disabled
/// - `disabled-checked`    : value=true,  disabled
///
/// 寸法: 24×24 / radius 4 / 枠 1px。チェック時は brandPrimary 塗りで
/// 中央に白チェック。タップ領域は周囲 16px 余白で 56dp を満たすように
/// 親側で確保することを推奨（Material `Checkbox` と同じ運用）。
@immutable
class TofuCheckbox extends StatelessWidget {
  const TofuCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  bool get _disabled => onChanged == null;

  @override
  Widget build(BuildContext context) {
    final Color bg = _disabled
        ? TofuTokens.bgMuted
        : (value ? TofuTokens.brandPrimary : TofuTokens.bgSurface);
    final Color border = _disabled
        ? TofuTokens.borderSubtle
        : (value ? TofuTokens.brandPrimary : TofuTokens.borderDefault);
    final Color checkColor = _disabled
        ? TofuTokens.textDisabled
        : TofuTokens.brandOnPrimary;

    final Widget box = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(TofuTokens.radiusSm),
      ),
      child: value
          ? Icon(Icons.check_rounded, size: 18, color: checkColor)
          : null,
    );

    if (_disabled) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged!(!value),
      child: box,
    );
  }
}
