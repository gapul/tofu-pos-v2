import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Figma `Atoms/Button` (ComponentSet `22:2`) を Flutter で再現したボタン。
///
/// Figma 上のバリエーション軸:
/// - variant: `primary | secondary | danger | ghost`
/// - size:    `md | lg | xl`
/// - state:   `default | disabled` (hover / pressed は Material の overlay)
enum TofuButtonVariant {
  /// 進める方向の確定操作（会計確定・提供完了など）。brandPrimary 塗り。
  primary,

  /// 補助的な確定操作。bgSurface + borderDefault。
  secondary,

  /// 破壊的操作（取消・削除）。dangerBgStrong 塗り。確定系と隣接させない。
  danger,

  /// 戻る・キャンセル等、視覚優先度を抑えたい操作。塗り・枠なしの text-only。
  ghost,
}

/// Figma `size` 軸。`md/lg/xl` はいずれも POS 用途で 56dp 以上を満たす。
enum TofuButtonSize {
  /// 56h / py16 px20 / radius 8 / body-md-bold。一般操作。
  md,

  /// 60h / py16 px24 / radius 12 / body-md-bold。主要操作（会計確定など）。
  lg,

  /// 68h / py20 px32 / radius 12 / body-lg-bold。最重要操作。
  xl,
}

/// アプリ標準ボタン。`TofuTokens.*` のみを参照する。
@immutable
class TofuButton extends StatelessWidget {
  const TofuButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = TofuButtonVariant.primary,
    this.size = TofuButtonSize.md,
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
    final TofuButtonSize s = size;
    final TofuButtonVariant v = variant;

    final double minHeight;
    final EdgeInsets padding;
    final double radius;
    final double iconSize;
    final TextStyle textStyle;

    switch (s) {
      case TofuButtonSize.md:
        minHeight = 56;
        padding = const EdgeInsets.symmetric(
          horizontal: TofuTokens.space6,
          vertical: TofuTokens.space5,
        );
        radius = TofuTokens.radiusMd;
        iconSize = 20;
        textStyle = TofuTextStyles.bodyMdBold;
      case TofuButtonSize.lg:
        minHeight = 60;
        padding = const EdgeInsets.symmetric(
          horizontal: TofuTokens.space7,
          vertical: TofuTokens.space5,
        );
        radius = TofuTokens.radiusLg;
        iconSize = 22;
        textStyle = TofuTextStyles.bodyMdBold;
      case TofuButtonSize.xl:
        minHeight = 68;
        padding = const EdgeInsets.symmetric(
          horizontal: TofuTokens.space8,
          vertical: TofuTokens.space6,
        );
        radius = TofuTokens.radiusLg;
        iconSize = 24;
        textStyle = TofuTextStyles.bodyLgBold;
    }

    final Color bg;
    final Color fg;
    final Color? border;
    final Color disabledBg;
    final Color disabledFg;

    switch (v) {
      case TofuButtonVariant.primary:
        bg = TofuTokens.brandPrimary;
        fg = TofuTokens.brandOnPrimary;
        border = null;
        disabledBg = TofuTokens.bgMuted;
        disabledFg = TofuTokens.textDisabled;
      case TofuButtonVariant.secondary:
        bg = TofuTokens.bgSurface;
        fg = TofuTokens.textPrimary;
        border = TofuTokens.borderDefault;
        disabledBg = TofuTokens.bgMuted;
        disabledFg = TofuTokens.textDisabled;
      case TofuButtonVariant.danger:
        bg = TofuTokens.dangerBgStrong;
        fg = TofuTokens.brandOnPrimary;
        border = null;
        disabledBg = TofuTokens.bgMuted;
        disabledFg = TofuTokens.textDisabled;
      case TofuButtonVariant.ghost:
        bg = Colors.transparent;
        fg = TofuTokens.textSecondary;
        border = null;
        disabledBg = Colors.transparent;
        disabledFg = TofuTokens.textDisabled;
    }

    final VoidCallback? handler = loading ? null : onPressed;
    final bool isDisabled = handler == null;
    final Color effectiveBg = isDisabled ? disabledBg : bg;
    final Color effectiveFg = isDisabled ? disabledFg : fg;

    final ButtonStyle style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(0, minHeight)),
      padding: WidgetStatePropertyAll<EdgeInsets>(padding),
      textStyle: WidgetStatePropertyAll<TextStyle>(textStyle),
      backgroundColor: WidgetStatePropertyAll<Color>(effectiveBg),
      foregroundColor: WidgetStatePropertyAll<Color>(effectiveFg),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return effectiveFg.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return effectiveFg.withValues(alpha: 0.06);
        }
        return null;
      }),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: border != null
              ? BorderSide(color: border)
              : BorderSide.none,
        ),
      ),
      elevation: const WidgetStatePropertyAll<double>(0),
    );

    final Widget child = loading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: iconSize),
                SizedBox(
                  width: s == TofuButtonSize.md
                      ? TofuTokens.space3
                      : TofuTokens.space4,
                ),
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

    final Widget button = TextButton(
      style: style,
      onPressed: handler,
      child: child,
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
