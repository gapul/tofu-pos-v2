import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/format.dart';
import '../../../../domain/entities/product.dart';

/// 商品ボタン（仕様書 §9.2）。
///
/// 表示色（[Product.displayColor]）があれば商品自体のイメージカラーで着色し、
/// 文字を読まずに判別できるようにする。
class ProductButton extends StatelessWidget {
  const ProductButton({
    required this.product,
    required this.cartCount,
    required this.stockEnabled,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final Product product;
  final int cartCount;
  final bool stockEnabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final bool soldOut = stockEnabled && product.stock <= 0;
    final bool reachedMax = stockEnabled && cartCount >= product.stock;
    final bool disabled = soldOut || reachedMax;

    final Color baseColor = product.displayColor != null
        ? Color(product.displayColor!)
        : TofuTokens.brandPrimarySubtle;
    final bool dark = baseColor.computeLuminance() < 0.5;
    final Color fg = soldOut
        ? TofuTokens.textDisabled
        : (dark ? TofuTokens.brandOnPrimary : TofuTokens.textPrimary);
    final Color displayColor = disabled ? TofuTokens.gray100 : baseColor;

    return Semantics(
      button: true,
      enabled: !disabled,
      label:
          '${product.name} ${TofuFormat.yen(product.price)}'
          '${stockEnabled ? ' 残り${product.stock}' : ''}',
      child: Material(
        color: displayColor,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
          onTap: disabled ? null : onTap,
          onLongPress: disabled ? null : onLongPress,
          child: Container(
            padding: const EdgeInsets.all(TofuTokens.space5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
              border: Border.all(
                color: disabled
                    ? TofuTokens.borderSubtle
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      product.name,
                      style: TofuTextStyles.bodyLgBold.copyWith(color: fg),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                            soldOut ? '完売' : '残${product.stock}',
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
                if (cartCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: TofuTokens.brandAccent,
                        shape: BoxShape.circle,
                        boxShadow: TofuTokens.elevationSm,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$cartCount',
                        style: TofuTextStyles.bodyMdBold.copyWith(
                          color: TofuTokens.brandOnPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
