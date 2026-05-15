import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_button.dart';

/// Figma `Organisms/ConfirmModal` (id `39:24`) を Flutter で再現。
///
/// variant:
///  - `type=standard` (39:2): info アイコン + primary 確定ボタン
///  - `type=destructive` (39:13): warning アイコン + danger 確定ボタン
///
/// Figma 仕様 (standard):
///   - container: 480 × 292、cornerRadius 24、padding (32/32/24/32)、gap 24
///   - vertical layout、`TofuButton` lg を 2 つ右寄せ
///
/// 仕様書 §12.1: 破壊的操作は赤色 + アイコン、デフォルトフォーカスはキャンセル側、
/// 確定 / 破壊ボタンと隣接させない。
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
    final Color iconBg = destructive ? TofuTokens.dangerBg : TofuTokens.infoBg;

    return Dialog(
      backgroundColor: TofuTokens.bgCanvas,
      shape: RoundedRectangleBorder(
        // Figma cornerRadius 24 == radius2xl
        borderRadius: BorderRadius.circular(TofuTokens.radius2xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          // Figma padding: top32 / right32 / bottom24 / left32
          padding: const EdgeInsets.fromLTRB(
            TofuTokens.space8, // 32
            TofuTokens.space8, // 32
            TofuTokens.space8, // 32
            TofuTokens.space7, // 24
          ),
          child: Column(
            // Figma layoutMode VERTICAL, itemSpacing 24
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- header (icon + title) ---
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(TofuTokens.space3),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
                    ),
                    child: Icon(effectiveIcon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: TofuTokens.space4),
                  Expanded(child: Text(title, style: TofuTextStyles.h3)),
                ],
              ),
              const SizedBox(height: TofuTokens.space6), // 24
              // --- body ---
              Text(message, style: TofuTextStyles.bodyMd),
              const SizedBox(height: TofuTokens.space6), // 24
              // --- actions (右寄せ, 確定/破壊と隣接させない) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  // デフォルトフォーカスはキャンセル側 (誤タップ防止)。
                  Focus(
                    autofocus: true,
                    child: TofuButton(
                      label: cancelLabel,
                      variant: TofuButtonVariant.secondary,
                      size: TofuButtonSize.lg,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
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
                    size: TofuButtonSize.lg,
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
