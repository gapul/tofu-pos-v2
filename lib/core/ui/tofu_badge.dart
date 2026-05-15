import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Atoms/Badge` (ComponentSet `25:26`) を Flutter で再現。
///
/// variant 軸 (背景 / 文字色):
/// - `neutral` : bgMuted        / textPrimary
/// - `info`    : infoBg         / infoText
/// - `success` : successBg      / successText
/// - `warning` : warningBg      / warningText
/// - `danger`  : dangerBg       / dangerText
/// - `brand`   : brandPrimarySubtle / brandPrimary
///
/// size 軸:
/// - `sm`: py4 px8  / font 12 (caption-bold)
/// - `md`: py8 px12 / font 14 (body-sm-bold)
///
/// すべて radius=full のピル形状。
enum TofuBadgeVariant { neutral, info, success, warning, danger, brand }

enum TofuBadgeSize { sm, md }

@immutable
class TofuBadge extends StatelessWidget {
  const TofuBadge({
    required this.label,
    super.key,
    this.variant = TofuBadgeVariant.neutral,
    this.size = TofuBadgeSize.sm,
  });

  final String label;
  final TofuBadgeVariant variant;
  final TofuBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg}) c = switch (variant) {
      TofuBadgeVariant.neutral => (
        bg: TofuTokens.bgMuted,
        fg: TofuTokens.textPrimary,
      ),
      TofuBadgeVariant.info => (bg: TofuTokens.infoBg, fg: TofuTokens.infoText),
      TofuBadgeVariant.success => (
        bg: TofuTokens.successBg,
        fg: TofuTokens.successText,
      ),
      TofuBadgeVariant.warning => (
        bg: TofuTokens.warningBg,
        fg: TofuTokens.warningText,
      ),
      TofuBadgeVariant.danger => (
        bg: TofuTokens.dangerBg,
        fg: TofuTokens.dangerText,
      ),
      TofuBadgeVariant.brand => (
        bg: TofuTokens.brandPrimarySubtle,
        fg: TofuTokens.brandPrimary,
      ),
    };

    final ({EdgeInsets padding, TextStyle textStyle}) m = switch (size) {
      TofuBadgeSize.sm => (
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space3,
          vertical: TofuTokens.space2,
        ),
        textStyle: TofuTextStyles.captionBold,
      ),
      TofuBadgeSize.md => (
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space4,
          vertical: TofuTokens.space3,
        ),
        textStyle: TofuTextStyles.bodySmBold,
      ),
    };

    return Container(
      padding: m.padding,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(TofuTokens.radiusFull),
      ),
      child: Text(label, style: m.textStyle.copyWith(color: c.fg)),
    );
  }
}
