import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'lordicon.dart';

/// Figma `Atoms/Button` (ComponentSet `22:2`) を Flutter で再現したボタン。
///
/// Figma 上のバリエーション軸 (Figma REST `nodes?ids=22:2` から抽出):
/// - variant: `primary | secondary | danger | ghost`
/// - size:    `md | lg | xl`
/// - state:   `default | disabled`
///   (hover / pressed / focused / loading は Figma に variant が無く、
///    Material の overlay と本ウィジェットの scale アニメで再現)
///
/// 抽出した Figma 値 (各 variant 共通の size 軸):
/// - md: h=56, padding=(16,20,16,20), gap=8,  radius=8,  text=16/24 w600
/// - lg: h=60, padding=(16,24,16,24), gap=12, radius=12, text=18/28 w600
/// - xl: h=68, padding=(20,32,20,32), gap=12, radius=12, text=20/28 w500
///
/// 色 (Figma `Atoms/Button` から):
/// - primary  : bg `aiPrimary (#173A5E)`  / text `brandOnPrimary (#FBF8F1)`
/// - secondary: bg `bgSurface (#F5EFE2)`  / border `borderDefault (#C9B57C)` / text `textPrimary (#161513)`
/// - danger   : bg `dangerBgStrong (#9A2E2E)` / text `brandOnPrimary (#FBF8F1)`
/// - ghost    : bg `transparent` / text `textPrimary (#161513)`
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
  /// 56h / py16 px20 / radius 8 / body-md-bold (16/24 w600)。一般操作。
  md,

  /// 60h / py16 px24 / radius 12 / body-lg-bold (18/28 w600)。主要操作。
  lg,

  /// 68h / py20 px32 / radius 12 / h4 (20/28 w500)。最重要操作。
  xl,
}

/// アプリ標準ボタン。`TofuTokens.*` のみを参照する。
///
/// インタラクション:
/// - 押下中: scale 0.97 (100ms, ease-out) で物理的フィードバック
/// - hover/pressed: Material の `overlayColor` で foreground の半透明被せ
/// - loading: ラベルを spinner にクロスフェード (200ms)
/// - icon vs lordicon: `lordicon` を渡すと `Lordicon` widget を、
///   `icon` を渡すと従来通り `Icon(IconData)` を表示する。両方渡された場合は
///   `lordicon` が優先される (アセット未配置時は Lordicon が自動で
///   `icon` (フォールバック) を Material Icon として表示する)。
@immutable
class TofuButton extends StatefulWidget {
  const TofuButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = TofuButtonVariant.primary,
    this.size = TofuButtonSize.md,
    this.icon,
    this.lordicon,
    this.fullWidth = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final TofuButtonVariant variant;
  final TofuButtonSize size;

  /// 静的アイコン (Material Icons)。後方互換用。
  final IconData? icon;

  /// Lordicon の name (`assets/lordicons/<name>.json`)。
  /// 指定時は `icon` より優先。アセット未配置時は `icon` (なければ
  /// `Icons.image_outlined`) に自動フォールバックする。
  final String? lordicon;

  final bool fullWidth;
  final bool loading;

  @override
  State<TofuButton> createState() => _TofuButtonState();
}

class _TofuButtonState extends State<TofuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // initState で確実に生成しておく (late 遅延初期化だと
    // disabled で一度も参照されないまま dispose に到達した際に
    // ticker 解決が失敗する)。
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _handleDown(_) => _pressCtrl.forward();
  void _handleUp(_) => _pressCtrl.reverse();
  void _handleCancel() => _pressCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    final TofuButtonSize s = widget.size;
    final TofuButtonVariant v = widget.variant;

    final double minHeight;
    final EdgeInsets padding;
    final double radius;
    final double iconSize;
    final TextStyle textStyle;
    final double gap;

    switch (s) {
      case TofuButtonSize.md:
        minHeight = 56;
        padding = const EdgeInsets.symmetric(
          horizontal: TofuTokens.space6, // 20
          vertical: TofuTokens.space5, // 16
        );
        radius = TofuTokens.radiusMd; // 8
        iconSize = 20;
        textStyle = TofuTextStyles.bodyMdBold; // 16/24 w600
        gap = TofuTokens.space3; // 8
      case TofuButtonSize.lg:
        minHeight = 60;
        padding = const EdgeInsets.symmetric(
          horizontal: TofuTokens.space7, // 24
          vertical: TofuTokens.space5, // 16
        );
        radius = TofuTokens.radiusLg; // 12
        iconSize = 22;
        // Figma 厳密値: 18/28 w600 = bodyLgBold (旧実装は bodyMdBold で
        // 2px 小さかった)。
        textStyle = TofuTextStyles.bodyLgBold;
        gap = TofuTokens.space4; // 12
      case TofuButtonSize.xl:
        minHeight = 68;
        padding = const EdgeInsets.symmetric(
          horizontal: TofuTokens.space8, // 32
          vertical: TofuTokens.space6, // 20
        );
        radius = TofuTokens.radiusLg; // 12
        iconSize = 24;
        // Figma 厳密値: 20/28 w500 = h4 (旧実装は bodyLgBold = 18/28 w600
        // で 2px 小さく、weight も異なっていた)。
        textStyle = TofuTextStyles.h4;
        gap = TofuTokens.space4; // 12
    }

    final Color bg;
    final Color fg;
    final Color? border;
    final Color disabledBg;
    final Color disabledFg;

    switch (v) {
      case TofuButtonVariant.primary:
        bg = TofuTokens.brandPrimary; // #173A5E
        fg = TofuTokens.brandOnPrimary; // #FBF8F1
        border = null;
        disabledBg = TofuTokens.bgMuted;
        disabledFg = TofuTokens.textDisabled;
      case TofuButtonVariant.secondary:
        bg = TofuTokens.bgSurface; // #F5EFE2
        fg = TofuTokens.textPrimary; // #161513
        border = TofuTokens.borderDefault; // #C9B57C
        disabledBg = TofuTokens.bgMuted;
        disabledFg = TofuTokens.textDisabled;
      case TofuButtonVariant.danger:
        bg = TofuTokens.dangerBgStrong; // #9A2E2E
        fg = TofuTokens.brandOnPrimary;
        border = null;
        disabledBg = TofuTokens.bgMuted;
        disabledFg = TofuTokens.textDisabled;
      case TofuButtonVariant.ghost:
        bg = Colors.transparent;
        // Figma 厳密値: textPrimary (#161513)。旧実装は textSecondary
        // (#2A2825) で僅かに薄かった。
        fg = TofuTokens.textPrimary;
        border = null;
        disabledBg = Colors.transparent;
        disabledFg = TofuTokens.textDisabled;
    }

    final VoidCallback? handler = widget.loading ? null : widget.onPressed;
    final bool isDisabled = handler == null;
    final Color effectiveBg = isDisabled ? disabledBg : bg;
    final Color effectiveFg = isDisabled ? disabledFg : fg;
    final TextStyle effectiveTextStyle = textStyle.copyWith(color: effectiveFg);

    final ButtonStyle style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(0, minHeight)),
      padding: WidgetStatePropertyAll<EdgeInsets>(padding),
      textStyle: WidgetStatePropertyAll<TextStyle>(effectiveTextStyle),
      backgroundColor: WidgetStatePropertyAll<Color>(effectiveBg),
      foregroundColor: WidgetStatePropertyAll<Color>(effectiveFg),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return effectiveFg.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return effectiveFg.withValues(alpha: 0.06);
        }
        if (states.contains(WidgetState.focused)) {
          return effectiveFg.withValues(alpha: 0.08);
        }
        return null;
      }),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: border != null ? BorderSide(color: border) : BorderSide.none,
        ),
      ),
      elevation: const WidgetStatePropertyAll<double>(0),
      // pressed/hovered 時もデフォルトの focus 装飾を抑止。
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      animationDuration: const Duration(milliseconds: 120),
    );

    final Widget labelWidget = Text(
      widget.label,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );

    final Widget spinner = SizedBox(
      width: iconSize,
      height: iconSize,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
      ),
    );

    // loading 中は spinner のみ描画 (ラベル/アイコンは構築しない)。
    // テスト互換のため、loading=true で `find.text(label)` は findsNothing
    // となるよう、即時切り替えする。
    final Widget content = widget.loading
        ? spinner
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.lordicon != null) ...<Widget>[
                Lordicon(
                  name: widget.lordicon!,
                  size: iconSize,
                  color: effectiveFg,
                  fallbackIcon: widget.icon ?? Icons.circle_outlined,
                  // ボタン上ではホバーで再生（マウス環境）。
                  trigger: LordiconTrigger.hover,
                ),
                SizedBox(width: gap),
              ] else if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: iconSize),
                SizedBox(width: gap),
              ],
              Flexible(child: labelWidget),
            ],
          );

    final Widget button = TextButton(
      style: style,
      onPressed: handler,
      child: content,
    );

    // 押下時 scale 0.97 のマイクロインタラクション。
    // 無効時はジェスチャー無効化しつつ button 本体は描画する。
    final Widget interactive = isDisabled
        ? button
        : Listener(
            onPointerDown: _handleDown,
            onPointerUp: _handleUp,
            onPointerCancel: (_) => _handleCancel(),
            child: ScaleTransition(scale: _scale, child: button),
          );

    return widget.fullWidth
        ? SizedBox(width: double.infinity, child: interactive)
        : interactive;
  }
}
