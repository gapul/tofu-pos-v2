import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum TofuStatusTone { info, success, warning, danger, neutral }

/// バナー・チップ・通知タグの共通表現（仕様書 §12.1: 色 + アイコン + テキストの3重）。
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    super.key,
    this.icon,
    this.tone = TofuStatusTone.neutral,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final TofuStatusTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color border, Color text, Color iconColor}) palette =
        switch (tone) {
          TofuStatusTone.info => (
            bg: TofuTokens.infoBg,
            border: TofuTokens.infoBorder,
            text: TofuTokens.infoText,
            iconColor: TofuTokens.infoIcon,
          ),
          TofuStatusTone.success => (
            bg: TofuTokens.successBg,
            border: TofuTokens.successBorder,
            text: TofuTokens.successText,
            iconColor: TofuTokens.successIcon,
          ),
          TofuStatusTone.warning => (
            bg: TofuTokens.warningBg,
            border: TofuTokens.warningBorder,
            text: TofuTokens.warningText,
            iconColor: TofuTokens.warningIcon,
          ),
          TofuStatusTone.danger => (
            bg: TofuTokens.dangerBg,
            border: TofuTokens.dangerBorder,
            text: TofuTokens.dangerText,
            iconColor: TofuTokens.dangerIcon,
          ),
          TofuStatusTone.neutral => (
            bg: TofuTokens.bgSurface,
            border: TofuTokens.borderSubtle,
            text: TofuTokens.textSecondary,
            iconColor: TofuTokens.textTertiary,
          ),
        };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? TofuTokens.space3 : TofuTokens.space4,
        vertical: dense ? TofuTokens.space2 : TofuTokens.space3,
      ),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 14 : 16, color: palette.iconColor),
            const SizedBox(width: TofuTokens.space2),
          ],
          Text(
            label,
            style: (dense ? TofuTextStyles.caption : TofuTextStyles.bodySmBold)
                .copyWith(color: palette.text),
          ),
        ],
      ),
    );
  }
}
