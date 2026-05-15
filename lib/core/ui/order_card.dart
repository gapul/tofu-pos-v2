import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_badge.dart';
import 'tofu_button.dart';

/// Figma `Molecules/Cards/OrderCard` (id `37:45`) を Flutter で再現。
///
/// 注文カード。`status` で表示色とアクションが変わる:
/// - `pending`: 通常配色 + 「提供完了」「キャンセル」ボタン。
/// - `delivered`: 成功色アクセント + アクション非表示。
/// - `cancelled`: 抑制配色 (textDisabled) + 取り消し線。
enum OrderCardStatus { pending, delivered, cancelled }

@immutable
class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.ticketLabel,
    required this.status,
    required this.lines,
    required this.totalText,
    super.key,
    this.placedAtText,
    this.onDeliver,
    this.onCancel,
    this.onTap,
  });

  /// 整理券番号 (例: '042')。
  final String ticketLabel;
  final OrderCardStatus status;

  /// 行頭バリエーション要約 (例: ['中盛 × 2', 'おでん × 1'])。
  final List<String> lines;

  /// 合計金額 (整形済み)。
  final String totalText;

  /// 受付時刻表示 (例: '12:34')。
  final String? placedAtText;

  final VoidCallback? onDeliver;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color border, TofuBadgeVariant badge, String badgeLabel})
    s = switch (status) {
      OrderCardStatus.pending => (
        bg: TofuTokens.bgSurface,
        border: TofuTokens.borderSubtle,
        badge: TofuBadgeVariant.warning,
        badgeLabel: '提供前',
      ),
      OrderCardStatus.delivered => (
        bg: TofuTokens.successBg,
        border: TofuTokens.successBorder,
        badge: TofuBadgeVariant.success,
        badgeLabel: '提供済',
      ),
      OrderCardStatus.cancelled => (
        bg: TofuTokens.bgMuted,
        border: TofuTokens.borderSubtle,
        badge: TofuBadgeVariant.danger,
        badgeLabel: '取消',
      ),
    };
    final bool muted = status == OrderCardStatus.cancelled;
    final Color textColor = muted
        ? TofuTokens.textDisabled
        : TofuTokens.textPrimary;
    final TextDecoration? deco = muted ? TextDecoration.lineThrough : null;

    final Widget card = Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: s.border),
        boxShadow: status == OrderCardStatus.pending
            ? TofuTokens.elevationSm
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                ticketLabel,
                style: TofuTextStyles.numberLg.copyWith(
                  color: textColor,
                  decoration: deco,
                ),
              ),
              const SizedBox(width: TofuTokens.space3),
              TofuBadge(label: s.badgeLabel, variant: s.badge),
              const Spacer(),
              if (placedAtText != null)
                Text(
                  placedAtText!,
                  style: TofuTextStyles.captionBold.copyWith(
                    color: TofuTokens.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: TofuTokens.space3),
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: TofuTextStyles.bodyMd.copyWith(
                  color: textColor,
                  decoration: deco,
                ),
              ),
            ),
          const SizedBox(height: TofuTokens.space3),
          Row(
            children: <Widget>[
              const Spacer(),
              Text(
                totalText,
                style: TofuTextStyles.numberMd.copyWith(
                  color: textColor,
                  decoration: deco,
                ),
              ),
            ],
          ),
          if (status == OrderCardStatus.pending &&
              (onDeliver != null || onCancel != null)) ...<Widget>[
            const SizedBox(height: TofuTokens.space4),
            Row(
              children: <Widget>[
                if (onCancel != null)
                  TofuButton(
                    label: 'キャンセル',
                    variant: TofuButtonVariant.danger,
                    onPressed: onCancel,
                  ),
                const Spacer(),
                if (onDeliver != null)
                  TofuButton(
                    label: '提供完了',
                    size: TofuButtonSize.lg,
                    onPressed: onDeliver,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      onTap: onTap,
      child: card,
    );
  }
}
