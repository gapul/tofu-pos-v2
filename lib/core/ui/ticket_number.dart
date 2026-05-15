import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Molecules/Display/TicketNumber` (id `380:19`) を Flutter で再現。
///
/// 整理券番号を統一フォーマットで表示するための表示専用 widget。
/// サイズ軸: `xs/sm/md/lg/display`。
enum TicketNumberSize { xs, sm, md, lg, display }

@immutable
class TicketNumber extends StatelessWidget {
  const TicketNumber({
    required this.number,
    super.key,
    this.size = TicketNumberSize.md,
    this.label,
    this.emphasized = true,
  });

  /// 整理券番号 (文字列)。表示時のパディング 0 は呼出側でやる。
  final String number;
  final TicketNumberSize size;

  /// 上段の小型ラベル (例: '整理券', '次回')。
  final String? label;

  /// `true`: brand 色塗りつぶし背景。`false`: 控えめ表示 (subtle 背景)。
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ({TextStyle number, TextStyle? label, EdgeInsets padding, double radius})
        m = switch (size) {
      TicketNumberSize.xs => (
        number: TofuTextStyles.bodyMdBold,
        label: TofuTextStyles.caption,
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space3,
          vertical: TofuTokens.space2,
        ),
        radius: TofuTokens.radiusSm,
      ),
      TicketNumberSize.sm => (
        number: TofuTextStyles.h4,
        label: TofuTextStyles.captionBold,
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space4,
          vertical: TofuTokens.space3,
        ),
        radius: TofuTokens.radiusMd,
      ),
      TicketNumberSize.md => (
        number: TofuTextStyles.h2,
        label: TofuTextStyles.captionBold,
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space5,
          vertical: TofuTokens.space4,
        ),
        radius: TofuTokens.radiusLg,
      ),
      TicketNumberSize.lg => (
        number: TofuTextStyles.h1,
        label: TofuTextStyles.bodySmBold,
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space7,
          vertical: TofuTokens.space5,
        ),
        radius: TofuTokens.radiusLg,
      ),
      TicketNumberSize.display => (
        number: TofuTextStyles.numberDisplay,
        label: TofuTextStyles.bodyLgBold,
        padding: const EdgeInsets.all(TofuTokens.space9),
        radius: TofuTokens.radius2xl,
      ),
    };

    final Color bg = emphasized
        ? TofuTokens.brandPrimary
        : TofuTokens.brandPrimarySubtle;
    final Color numberFg = emphasized
        ? TofuTokens.brandOnPrimary
        : TofuTokens.brandPrimary;
    final Color labelFg = emphasized
        ? TofuTokens.brandOnPrimary
        : TofuTokens.textTertiary;

    return Container(
      padding: m.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(m.radius),
        border: emphasized
            ? null
            : Border.all(color: TofuTokens.brandPrimaryBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label != null && m.label != null) ...<Widget>[
            Text(label!, style: m.label!.copyWith(color: labelFg)),
            const SizedBox(height: 2),
          ],
          Text(number, style: m.number.copyWith(color: numberFg)),
        ],
      ),
    );
  }
}
