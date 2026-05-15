import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_icon.dart';

/// Figma `Molecules/Navigation & Layout/Tab` (id `400:14`) を Flutter で再現。
///
/// タブナビ 1 要素。`active` で brand 色強調 + 下線。
@immutable
class TofuTab extends StatelessWidget {
  const TofuTab({
    required this.label,
    required this.active,
    super.key,
    this.icon,
    this.badgeCount,
    this.onTap,
  });

  final String label;
  final bool active;
  final TofuIconName? icon;

  /// 右肩バッジ数値 (0 や null なら非表示)。
  final int? badgeCount;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        active ? TofuTokens.brandPrimary : TofuTokens.textSecondary;
    final Color underline =
        active ? TofuTokens.brandPrimary : Colors.transparent;
    final TextStyle textStyle = (active
            ? TofuTextStyles.bodyMdBold
            : TofuTextStyles.bodyMd)
        .copyWith(color: fg);
    final bool hasBadge = badgeCount != null && badgeCount! > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: TofuTokens.touchMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space4,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: underline,
                width: TofuTokens.strokeThick,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                TofuIcon(icon!, size: 18, color: fg),
                const SizedBox(width: TofuTokens.space2),
              ],
              Text(label, style: textStyle),
              if (hasBadge) ...<Widget>[
                const SizedBox(width: TofuTokens.space2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TofuTokens.space2,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: TofuTokens.brandPrimary,
                    borderRadius:
                        BorderRadius.circular(TofuTokens.radiusFull),
                  ),
                  constraints: const BoxConstraints(minWidth: 20),
                  child: Text(
                    badgeCount!.toString(),
                    style: TofuTextStyles.captionBold.copyWith(
                      color: TofuTokens.brandOnPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
