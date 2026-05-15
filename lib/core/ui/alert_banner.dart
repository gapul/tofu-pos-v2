import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_icon.dart';

/// Figma `Molecules/Display/AlertBanner` (id `35:33`) を Flutter で再現。
///
/// 全幅の通知バナー。`variant` で配色とアイコンを切替。
enum AlertBannerVariant { info, success, warning, danger }

@immutable
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    required this.message,
    super.key,
    this.variant = AlertBannerVariant.info,
    this.title,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  final AlertBannerVariant variant;

  /// 上段タイトル (省略可)。
  final String? title;

  /// 本文。
  final String message;

  /// 右端のアクションボタンラベル。
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 閉じる × ボタン。指定があれば右端に表示。
  final VoidCallback? onClose;

  ({Color bg, Color border, Color text, Color icon, TofuIconName iconName})
  _palette() {
    switch (variant) {
      case AlertBannerVariant.info:
        return (
          bg: TofuTokens.infoBg,
          border: TofuTokens.infoBorder,
          text: TofuTokens.infoText,
          icon: TofuTokens.infoIcon,
          iconName: TofuIconName.info,
        );
      case AlertBannerVariant.success:
        return (
          bg: TofuTokens.successBg,
          border: TofuTokens.successBorder,
          text: TofuTokens.successText,
          icon: TofuTokens.successIcon,
          iconName: TofuIconName.check,
        );
      case AlertBannerVariant.warning:
        return (
          bg: TofuTokens.warningBg,
          border: TofuTokens.warningBorder,
          text: TofuTokens.warningText,
          icon: TofuTokens.warningIcon,
          iconName: TofuIconName.warning,
        );
      case AlertBannerVariant.danger:
        return (
          bg: TofuTokens.dangerBg,
          border: TofuTokens.dangerBorder,
          text: TofuTokens.dangerText,
          icon: TofuTokens.dangerIcon,
          iconName: TofuIconName.warning,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ({
      Color bg,
      Color border,
      Color text,
      Color icon,
      TofuIconName iconName,
    })
    p = _palette();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space4,
        vertical: TofuTokens.space3,
      ),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TofuIcon(p.iconName, size: 20, color: p.icon),
          const SizedBox(width: TofuTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!,
                    style: TofuTextStyles.bodyMdBold.copyWith(color: p.text),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TofuTextStyles.bodySm.copyWith(color: p.text),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(width: TofuTokens.space3),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: p.text,
                textStyle: TofuTextStyles.bodySmBold,
              ),
              child: Text(actionLabel!),
            ),
          ],
          if (onClose != null) ...<Widget>[
            const SizedBox(width: TofuTokens.space2),
            IconButton(
              tooltip: '閉じる',
              icon: TofuIcon(TofuIconName.x, size: 18, color: p.icon),
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
