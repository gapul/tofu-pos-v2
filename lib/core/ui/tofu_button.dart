import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// ボタンの主要バリアント（仕様書 §12.1）。
///
/// - primary: 進める方向の確定操作（会計確定・提供完了など）
/// - secondary: 補助的な確定操作
/// - outlined: フォーム上の中立操作
/// - danger: 破壊的操作（取消、削除）— 確定系と隣接させない
/// - ghost: 戻る・キャンセルなど、視覚的優先度を抑えたい操作
enum TofuButtonVariant { primary, secondary, outlined, danger, ghost }

enum TofuButtonSize {
  /// 一般操作: 56×56以上（仕様書 §12.1）
  regular,

  /// 主要操作（会計確定・提供完了など）: 72×72以上
  primary,
}

/// アプリ標準ボタン。タップターゲットを学祭環境向けに大きめに保つ。
class TofuButton extends StatelessWidget {
  const TofuButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = TofuButtonVariant.primary,
    this.size = TofuButtonSize.regular,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final TofuButtonVariant variant;
  final TofuButtonSize size;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final double minHeight = size == TofuButtonSize.primary
        ? TofuTokens.touchPrimary
        : TofuTokens.touchMin;

    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: size == TofuButtonSize.primary
          ? TofuTokens.space8
          : TofuTokens.space7,
      vertical: TofuTokens.space5,
    );

    final TextStyle textStyle = size == TofuButtonSize.primary
        ? TofuTextStyles.bodyLgBold
        : TofuTextStyles.bodyMdBold;

    final ButtonStyle baseStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(0, minHeight)),
      padding: WidgetStatePropertyAll<EdgeInsets>(padding),
      textStyle: WidgetStatePropertyAll<TextStyle>(textStyle),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        ),
      ),
    );

    final Widget child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 22),
                const SizedBox(width: TofuTokens.space3),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final VoidCallback? handler = loading ? null : onPressed;

    final Widget button = switch (variant) {
      TofuButtonVariant.primary => FilledButton(
        style: baseStyle.merge(
          FilledButton.styleFrom(
            backgroundColor: TofuTokens.brandPrimary,
            foregroundColor: TofuTokens.brandOnPrimary,
            disabledBackgroundColor: TofuTokens.gray300,
            disabledForegroundColor: TofuTokens.textDisabled,
          ),
        ),
        onPressed: handler,
        child: child,
      ),
      TofuButtonVariant.secondary => FilledButton(
        style: baseStyle.merge(
          FilledButton.styleFrom(
            backgroundColor: TofuTokens.brandPrimarySubtleStrong,
            foregroundColor: TofuTokens.brandPrimary,
          ),
        ),
        onPressed: handler,
        child: child,
      ),
      TofuButtonVariant.outlined => OutlinedButton(
        style: baseStyle.merge(
          OutlinedButton.styleFrom(
            foregroundColor: TofuTokens.textPrimary,
            side: const BorderSide(color: TofuTokens.borderDefault),
          ),
        ),
        onPressed: handler,
        child: child,
      ),
      TofuButtonVariant.danger => FilledButton(
        style: baseStyle.merge(
          FilledButton.styleFrom(
            backgroundColor: TofuTokens.dangerBgStrong,
            foregroundColor: TofuTokens.brandOnPrimary,
          ),
        ),
        onPressed: handler,
        child: child,
      ),
      TofuButtonVariant.ghost => TextButton(
        style: baseStyle.merge(
          TextButton.styleFrom(foregroundColor: TofuTokens.textSecondary),
        ),
        onPressed: handler,
        child: child,
      ),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
