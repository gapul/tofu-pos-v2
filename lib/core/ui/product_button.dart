import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_badge.dart';

/// Figma `Molecules/Cards/ProductButton` (id `32:24`) を Flutter で再現。
///
/// 商品グリッドのタップターゲット。
/// - state: `available | lowStock | outOfStock | inCart`
/// - color: `defaultColor | brand`
enum ProductButtonState { available, lowStock, outOfStock, inCart }

enum ProductButtonColor { defaultColor, brand }

@immutable
class ProductButton extends StatelessWidget {
  const ProductButton({
    required this.name,
    required this.priceText,
    required this.state,
    super.key,
    this.color = ProductButtonColor.defaultColor,
    this.onPressed,
    this.cartCount,
    this.stockText,
  });

  final String name;
  final String priceText;
  final ProductButtonState state;
  final ProductButtonColor color;
  final VoidCallback? onPressed;

  /// `inCart` 状態時にカード右上に表示するカウントバッジ。
  final int? cartCount;

  /// `lowStock` の残数表示 (例: '残3')。
  final String? stockText;

  @override
  Widget build(BuildContext context) {
    final bool brand = color == ProductButtonColor.brand;
    final bool inCart = state == ProductButtonState.inCart;
    final bool out = state == ProductButtonState.outOfStock;
    final bool low = state == ProductButtonState.lowStock;

    final Color bg;
    final Color border;
    final Color fg;
    final Color subFg;
    final double borderW;

    if (out) {
      bg = TofuTokens.bgMuted;
      border = TofuTokens.borderSubtle;
      fg = TofuTokens.textDisabled;
      subFg = TofuTokens.textDisabled;
      borderW = TofuTokens.strokeHairline;
    } else if (inCart) {
      bg = brand
          ? TofuTokens.brandPrimary
          : TofuTokens.brandPrimarySubtleStrong;
      border = TofuTokens.brandPrimary;
      fg = brand ? TofuTokens.brandOnPrimary : TofuTokens.brandPrimary;
      subFg = brand ? TofuTokens.brandOnPrimary : TofuTokens.brandPrimary;
      borderW = TofuTokens.strokeThick;
    } else if (brand) {
      bg = TofuTokens.brandPrimarySubtle;
      border = TofuTokens.brandPrimaryBorder;
      fg = TofuTokens.brandPrimary;
      subFg = TofuTokens.textSecondary;
      borderW = TofuTokens.strokeHairline;
    } else {
      bg = TofuTokens.bgSurface;
      border = TofuTokens.borderDefault;
      fg = TofuTokens.textPrimary;
      subFg = TofuTokens.textTertiary;
      borderW = TofuTokens.strokeHairline;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        onTap: out ? null : onPressed,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: TofuTokens.touchPrimary,
            minWidth: 120,
          ),
          padding: const EdgeInsets.all(TofuTokens.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
            border: Border.all(color: border, width: borderW),
          ),
          child: Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    name,
                    style: TofuTextStyles.bodyMdBold.copyWith(color: fg),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: TofuTokens.space2),
                  Text(
                    priceText,
                    style: TofuTextStyles.bodySm.copyWith(color: subFg),
                  ),
                  if (low && stockText != null) ...<Widget>[
                    const SizedBox(height: TofuTokens.space2),
                    TofuBadge(
                      label: stockText!,
                      variant: TofuBadgeVariant.warning,
                    ),
                  ] else if (out) ...<Widget>[
                    const SizedBox(height: TofuTokens.space2),
                    const TofuBadge(
                      label: '在庫切れ',
                      variant: TofuBadgeVariant.danger,
                    ),
                  ],
                ],
              ),
              if (inCart && cartCount != null && cartCount! > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TofuTokens.space2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: brand
                          ? TofuTokens.brandOnPrimary
                          : TofuTokens.brandPrimary,
                      borderRadius: BorderRadius.circular(
                        TofuTokens.radiusFull,
                      ),
                    ),
                    child: Text(
                      cartCount!.toString(),
                      style: TofuTextStyles.captionBold.copyWith(
                        color: brand
                            ? TofuTokens.brandPrimary
                            : TofuTokens.brandOnPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
