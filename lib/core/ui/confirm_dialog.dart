import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_button.dart';

/// 不可逆・破壊的操作の確認モーダル（仕様書 §12.1）。
///
/// - 破壊系操作は赤色 + アイコンで明示
/// - デフォルトフォーカスはキャンセル側
/// - 確定ボタンと破壊ボタンは隣接させない
class TofuConfirmDialog extends StatelessWidget {
  const TofuConfirmDialog({
    required this.title,
    required this.message,
    super.key,
    this.confirmLabel = 'OK',
    this.cancelLabel = 'キャンセル',
    this.destructive = false,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'OK',
    String cancelLabel = 'キャンセル',
    bool destructive = false,
    IconData? icon,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => TofuConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final IconData effectiveIcon =
        icon ??
        (destructive ? Icons.warning_amber_rounded : Icons.help_outline);
    final Color iconColor = destructive
        ? TofuTokens.dangerIcon
        : TofuTokens.infoIcon;

    return Dialog(
      backgroundColor: TofuTokens.bgCanvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TofuTokens.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(TofuTokens.space7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(TofuTokens.space3),
                    decoration: BoxDecoration(
                      color: destructive
                          ? TofuTokens.dangerBg
                          : TofuTokens.infoBg,
                      borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
                    ),
                    child: Icon(effectiveIcon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: TofuTokens.space4),
                  Expanded(child: Text(title, style: TofuTextStyles.h3)),
                ],
              ),
              const SizedBox(height: TofuTokens.space5),
              Text(message, style: TofuTextStyles.bodyMd),
              const SizedBox(height: TofuTokens.space8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  // デフォルトフォーカス（最後のフォーカス対象）。
                  Focus(
                    autofocus: true,
                    child: TofuButton(
                      label: cancelLabel,
                      variant: TofuButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  // 破壊と確定の間に大きめのスペース（誤タップ防止）。
                  SizedBox(
                    width: destructive
                        ? TofuTokens.destructiveSpacing
                        : TofuTokens.adjacentSpacing,
                  ),
                  TofuButton(
                    label: confirmLabel,
                    variant: destructive
                        ? TofuButtonVariant.danger
                        : TofuButtonVariant.primary,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
