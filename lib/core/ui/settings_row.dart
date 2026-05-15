import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_icon.dart';

/// Figma `Molecules/Navigation & Layout/SettingsRow` (id `400:25`) を Flutter で再現。
///
/// 設定画面 1 行。leading icon + title (+ subtitle) + trailing (任意) + 右矢印。
@immutable
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    super.key,
    this.leadingIcon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.enabled = true,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;

  /// 左端アイコン。
  final TofuIconName? leadingIcon;

  /// 右端のトグル/値表示。chevron より左に配置。
  final Widget? trailing;

  final VoidCallback? onTap;

  /// `true` で title を danger 色に。
  final bool destructive;

  final bool enabled;

  /// `false` で右矢印を出さない (Toggle 行など)。
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final Color titleColor = !enabled
        ? TofuTokens.textDisabled
        : destructive
        ? TofuTokens.dangerText
        : TofuTokens.textPrimary;
    final Color subColor = enabled
        ? TofuTokens.textTertiary
        : TofuTokens.textDisabled;
    final Color iconColor = !enabled
        ? TofuTokens.textDisabled
        : destructive
        ? TofuTokens.dangerIcon
        : TofuTokens.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: TofuTokens.touchMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space4,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: TofuTokens.borderSubtle),
            ),
          ),
          child: Row(
            children: <Widget>[
              if (leadingIcon != null) ...<Widget>[
                TofuIcon(leadingIcon!, size: 22, color: iconColor),
                const SizedBox(width: TofuTokens.space4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: TofuTextStyles.bodyMdBold.copyWith(
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TofuTextStyles.bodySm.copyWith(color: subColor),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: TofuTokens.space3),
                trailing!,
              ],
              if (showChevron && onTap != null) ...<Widget>[
                const SizedBox(width: TofuTokens.space2),
                const TofuIcon(
                  TofuIconName.chevronRight,
                  size: 20,
                  color: TofuTokens.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
