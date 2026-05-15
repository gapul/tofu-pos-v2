import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/format.dart';
import '../../../../domain/entities/product.dart';

/// 商品ボタン（仕様書 §9.2 / Figma `03-Register-Products` → `ProductButton`）。
///
/// Figma 上の構造（`47:17` / `47:22` 等から抽出）:
/// - 174x130, padding 16, radius 12
/// - 上段: 商品名（bodyLgBold）
/// - 下段:
///   - quantity == 0 のとき: 「価格」 + 「在庫 N / 残り N / 在庫切れ」
///   - quantity >= 1 のとき: 「価格」 + 「− × N +」inline ステッパー
///
/// `quantity` は `CheckoutSession.countOf(product.id)` を渡す前提。
/// `onTap`/`onLongPress`: カードタップ全体の +1（既存挙動を維持）。
/// `onIncrement` / `onDecrement`: inline ステッパーの ± ボタン。
/// quantity > 0 の場合、`onTap` はステッパー表示中のカード地のタップで
/// `onIncrement` と同じ振る舞いになるように呼び出し側で揃える。
class ProductButton extends StatelessWidget {
  const ProductButton({
    required this.product,
    required this.cartCount,
    required this.stockEnabled,
    required this.onTap,
    required this.onLongPress,
    this.onIncrement,
    this.onDecrement,
    super.key,
  });

  final Product product;
  final int cartCount;
  final bool stockEnabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// inline ステッパーの「+」ボタン押下時。null の場合は `onTap` で代替する。
  final VoidCallback? onIncrement;

  /// inline ステッパーの「−」ボタン押下時。null の場合 quantity は非表示。
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final bool soldOut = stockEnabled && product.stock <= 0;
    final bool reachedMax = stockEnabled && cartCount >= product.stock;
    final bool inCart = cartCount > 0;
    final bool disabled = soldOut || (!inCart && reachedMax);

    final Color baseColor = product.displayColor != null
        ? Color(product.displayColor!)
        : TofuTokens.brandPrimarySubtle;
    final Color cardColor = soldOut
        ? TofuTokens.gray100
        : inCart
            ? TofuTokens.brandPrimarySubtleStrong
            : baseColor;
    final bool dark = cardColor.computeLuminance() < 0.5;
    final Color fg = soldOut
        ? TofuTokens.textDisabled
        : (dark ? TofuTokens.brandOnPrimary : TofuTokens.textPrimary);
    final Color borderColor = inCart && !soldOut
        ? TofuTokens.brandPrimary
        : disabled
            ? TofuTokens.borderSubtle
            : Colors.black.withValues(alpha: 0.06);

    return Semantics(
      button: true,
      enabled: !disabled,
      label:
          '${product.name} ${TofuFormat.yen(product.price)}'
          '${stockEnabled ? ' 残り${product.stock}' : ''}'
          '${inCart ? ' カート $cartCount 点' : ''}',
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
          onTap: disabled ? null : onTap,
          onLongPress: disabled ? null : onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TofuTokens.space5,
              vertical: TofuTokens.space4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
              border: Border.all(
                color: borderColor,
                width: inCart && !soldOut ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  product.name,
                  style: TofuTextStyles.bodyLgBold.copyWith(color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (inCart)
                  _InlineStepper(
                    price: product.price,
                    quantity: cartCount,
                    fg: fg,
                    canDecrement: onDecrement != null,
                    canIncrement: !reachedMax && onIncrement != null,
                    onIncrement: onIncrement ?? onTap,
                    onDecrement: onDecrement,
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        TofuFormat.yen(product.price),
                        style: TofuTextStyles.numberMd.copyWith(color: fg),
                      ),
                      if (stockEnabled)
                        Text(
                          soldOut
                              ? '在庫切れ'
                              : product.stock <= 3
                                  ? '残り ${product.stock}'
                                  : '在庫 ${product.stock}',
                          style: TofuTextStyles.captionBold.copyWith(
                            color: soldOut
                                ? TofuTokens.dangerText
                                : fg.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// カード内に埋め込む `− × N +` の inline ステッパー（Figma `Stepper`
/// frame `I47:17;361:10` を踏襲）。
class _InlineStepper extends StatelessWidget {
  const _InlineStepper({
    required this.price,
    required this.quantity,
    required this.fg,
    required this.canDecrement,
    required this.canIncrement,
    required this.onIncrement,
    this.onDecrement,
  });

  final dynamic price; // Money。`format.dart` 経由で表示する。
  final int quantity;
  final Color fg;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final Color stepBg = TofuTokens.brandOnPrimary.withValues(alpha: 0.6);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _StepButton(
          icon: Icons.remove,
          fg: fg,
          bg: stepBg,
          tooltip: '減らす',
          onPressed: canDecrement ? onDecrement : null,
        ),
        Expanded(
          child: Center(
            child: Text(
              '× $quantity',
              style: TofuTextStyles.numberMd.copyWith(color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          fg: fg,
          bg: stepBg,
          tooltip: '増やす',
          onPressed: canIncrement ? onIncrement : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.fg,
    required this.bg,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color fg;
  final Color bg;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: enabled ? bg : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              size: 20,
              color: enabled ? fg : fg.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
