import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 画面 body 冒頭に置く「ページ固有タイトル」(H2)。
///
/// Figma の構造変更 (PR-1) により、`AppHeader` はブランド固定
/// (「レジ」「キッチン」「呼び出し」「設定」「初期設定」) を保持し、
/// 各画面固有のタイトル (「お会計」「顧客属性」「商品選択」…) は
/// body 上部の H2 として描画する。
///
/// 構成:
///   - H2 タイトル
///   - 任意の subtitle (bodySm / textTertiary)
///   - 任意の leading widget (アイコン装飾など / `Lordicon` を想定)
///   - 任意の trailing actions
///
/// 既存の `PaneTitle` は左/右ペイン単位の小見出し用途であり、
/// ページ全体の H2 用途には本 widget を使う。
@immutable
class PageTitle extends StatelessWidget {
  const PageTitle({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// 外側 padding。未指定時は左右 [TofuTokens.space5] / 上下 [TofuTokens.space4]。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space4,
          ),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: TofuTokens.space3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: TofuTextStyles.h2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: TofuTokens.space1),
                  Text(
                    subtitle!,
                    style: TofuTextStyles.bodySm.copyWith(
                      color: TofuTokens.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(width: TofuTokens.space3),
            ..._interleave(actions, const SizedBox(width: TofuTokens.space2)),
          ],
        ],
      ),
    );
  }

  List<Widget> _interleave(List<Widget> items, Widget separator) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) out.add(separator);
      out.add(items[i]);
    }
    return out;
  }
}
