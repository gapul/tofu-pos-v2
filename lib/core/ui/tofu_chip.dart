import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Atoms/Chip` (ComponentSet `27:6`) を Flutter で再現したチップ。
///
/// state 軸:
/// - `unselected`: bgSurface + borderDefault + textPrimary
/// - `selected`:   brandPrimarySubtleStrong + borderFocus + textLink
///
/// 高さは Figma で 36px (py8 / px16 / font 14)。タップターゲットとして
/// やや小さいので、行内で十分な隣接余白を確保するか、Molecules 側で
/// 専用 hit-area を用意することを推奨。
@immutable
class TofuChip extends StatelessWidget {
  const TofuChip({
    required this.label,
    required this.selected,
    super.key,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected ? TofuTokens.brandPrimarySubtleStrong : TofuTokens.bgSurface;
    final Color border = selected ? TofuTokens.brandPrimary : TofuTokens.borderDefault;
    final Color fg = selected ? TofuTokens.brandPrimary : TofuTokens.textPrimary;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space3,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: TofuTokens.space2),
          ],
          Text(
            label,
            style: TofuTextStyles.bodySmBold.copyWith(color: fg),
          ),
        ],
      ),
    );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border),
        borderRadius: BorderRadius.circular(TofuTokens.radiusFull),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    );
  }
}
