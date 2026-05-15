import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 左ペイン / 右ペインの見出しを共通化する Molecule。
///
/// Figma `07-Kitchen-Home` 系（73:83 / 73:156）で確立し、Phase 5D の管理系
/// 4 画面でも繰り返し利用する。
///
/// 構成:
///   - 4dp × 24dp の縦バー (accent 色)
///   - h4 タイトル
///   - 任意の件数バッジ (bodySmBold / textTertiary)
///   - 任意のサブタイトル (bodySm / textTertiary)
///   - 任意の trailing widget (操作ボタンなど)
@immutable
class PaneTitle extends StatelessWidget {
  const PaneTitle({
    required this.title,
    super.key,
    this.accent = TofuTokens.brandPrimary,
    this.count,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final Color accent;
  final int? count;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: TofuTokens.space3),
        Text(title, style: TofuTextStyles.h4),
        if (count != null) ...<Widget>[
          const SizedBox(width: TofuTokens.space3),
          Text(
            '${count!}件',
            style: TofuTextStyles.bodySmBold.copyWith(
              color: TofuTokens.textTertiary,
            ),
          ),
        ],
        if (subtitle != null) ...<Widget>[
          const SizedBox(width: TofuTokens.space3),
          Flexible(
            child: Text(
              subtitle!,
              style: TofuTextStyles.bodySm.copyWith(
                color: TofuTokens.textTertiary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (trailing != null) ...<Widget>[
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}
