import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_icon.dart';

/// Figma `Molecules/Cards/KpiCard` (id `400:10`) を Flutter で再現。
///
/// ダッシュボード用 KPI カード。ラベル + 大型数値 + 補助テキスト/トレンド表記。
enum KpiTrend { up, down, flat }

@immutable
class KpiCard extends StatelessWidget {
  const KpiCard({
    required this.label,
    required this.valueText,
    super.key,
    this.unit,
    this.helperText,
    this.trend,
    this.trendText,
    this.icon,
  });

  /// カード上段のラベル。
  final String label;

  /// 大型数値文字列。整形済み。
  final String valueText;

  /// 単位 (例: '円', '件')。
  final String? unit;

  /// 補助テキスト (前日比など)。`trendText` と排他ではない。
  final String? helperText;

  final KpiTrend? trend;
  final String? trendText;
  final TofuIconName? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        color: TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: TofuTokens.borderSubtle),
        boxShadow: TofuTokens.elevationSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                TofuIcon(icon!, size: 20, color: TofuTokens.brandPrimary),
                const SizedBox(width: TofuTokens.space2),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TofuTextStyles.bodySmBold.copyWith(
                    color: TofuTokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TofuTokens.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  valueText,
                  style: TofuTextStyles.numberLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: TofuTokens.space2),
                Text(
                  unit!,
                  style: TofuTextStyles.bodyMd.copyWith(
                    color: TofuTokens.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          if (trend != null || helperText != null) ...<Widget>[
            const SizedBox(height: TofuTokens.space2),
            Row(
              children: <Widget>[
                if (trend != null) _TrendBadge(trend: trend!, text: trendText),
                if (trend != null && helperText != null)
                  const SizedBox(width: TofuTokens.space2),
                if (helperText != null)
                  Flexible(
                    child: Text(
                      helperText!,
                      style: TofuTextStyles.caption,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend, this.text});
  final KpiTrend trend;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, Color color}) v = switch (trend) {
      KpiTrend.up => (
        icon: Icons.arrow_upward_rounded,
        color: TofuTokens.successText,
      ),
      KpiTrend.down => (
        icon: Icons.arrow_downward_rounded,
        color: TofuTokens.dangerText,
      ),
      KpiTrend.flat => (
        icon: Icons.remove_rounded,
        color: TofuTokens.textTertiary,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(v.icon, size: 14, color: v.color),
        if (text != null) ...<Widget>[
          const SizedBox(width: 2),
          Text(
            text!,
            style: TofuTextStyles.captionBold.copyWith(color: v.color),
          ),
        ],
      ],
    );
  }
}
