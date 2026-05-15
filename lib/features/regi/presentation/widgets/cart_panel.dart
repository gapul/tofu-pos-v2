import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/num_stepper.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/product.dart';
import '../notifiers/checkout_session.dart';

/// カートパネル（仕様書 §9.2）。
///
/// - カート行の数量はフォントを大きく取り、誤入力に気付ける大きさで表示。
/// - 数量変更時は対象行をハイライト（recentlyChangedId と一致する行）。
class CartPanel extends StatelessWidget {
  const CartPanel({
    required this.session,
    required this.notifier,
    required this.products,
    required this.stockEnabled,
    required this.recentlyChangedId,
    required this.onCheckout,
    super.key,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final List<Product> products;
  final bool stockEnabled;
  final String? recentlyChangedId;
  final VoidCallback onCheckout;

  Product? _findProduct(String id) {
    for (final Product p in products) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TofuTokens.bgCanvas,
        border: Border(left: BorderSide(color: TofuTokens.borderSubtle)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TofuTokens.space5,
              vertical: TofuTokens.space5,
            ),
            child: Row(
              children: <Widget>[
                const Text('カート', style: TofuTextStyles.h4),
                const Spacer(),
                if (session.items.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      for (final OrderItem it in List<OrderItem>.from(
                        session.items,
                      )) {
                        notifier.removeProduct(it.productId);
                      }
                    },
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('全削除'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: session.items.isEmpty
                ? const _EmptyCart()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: TofuTokens.space3,
                    ),
                    itemCount: session.items.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: TofuTokens.space2,
                      color: TofuTokens.borderSubtle,
                    ),
                    itemBuilder: (c, i) {
                      final OrderItem it = session.items[i];
                      return _CartRow(
                        item: it,
                        product: _findProduct(it.productId),
                        stockEnabled: stockEnabled,
                        highlighted: recentlyChangedId == it.productId,
                        onChanged: (q) => notifier.setQuantity(
                          it.productId,
                          q,
                          maxStock: stockEnabled
                              ? _findProduct(it.productId)?.stock
                              : null,
                        ),
                        onRemove: () => notifier.removeProduct(it.productId),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(TofuTokens.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Summary(
                  label: '点数',
                  value:
                      '${session.items.fold<int>(0, (s, it) => s + it.quantity)} 点',
                ),
                const SizedBox(height: TofuTokens.space3),
                _Summary(
                  label: '小計',
                  value: TofuFormat.yen(session.totalPrice),
                  large: true,
                ),
                const SizedBox(height: TofuTokens.space5),
                FilledButton.icon(
                  onPressed: session.items.isEmpty ? null : onCheckout,
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('会計へ進む'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      TofuTokens.touchPrimary,
                    ),
                    backgroundColor: TofuTokens.brandPrimary,
                    foregroundColor: TofuTokens.brandOnPrimary,
                    textStyle: TofuTextStyles.bodyLgBold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.shopping_cart_outlined,
            size: 48,
            color: TofuTokens.textDisabled,
          ),
          const SizedBox(height: TofuTokens.space3),
          Text(
            '商品をタップしてカートに追加',
            style: TofuTextStyles.bodyMd.copyWith(
              color: TofuTokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.product,
    required this.stockEnabled,
    required this.highlighted,
    required this.onChanged,
    required this.onRemove,
  });

  final OrderItem item;
  final Product? product;
  final bool stockEnabled;
  final bool highlighted;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TofuTokens.motionShort,
      color: highlighted ? TofuTokens.brandPrimarySubtle : Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space4,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.productName,
                  style: TofuTextStyles.bodyLgBold,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${TofuFormat.yen(item.priceAtTime)} × ${item.quantity}',
                  style: TofuTextStyles.bodySm.copyWith(
                    color: TofuTokens.textTertiary,
                  ),
                ),
                const SizedBox(height: TofuTokens.space2),
                Text(
                  TofuFormat.yen(item.subtotal),
                  style: TofuTextStyles.numberMd,
                ),
              ],
            ),
          ),
          TofuNumStepper(
            value: item.quantity,
            onChanged: onChanged,
            min: 1,
            max: stockEnabled
                ? (product?.stock ?? item.quantity).clamp(1, 9999)
                : 99,
            size: TofuNumStepperSize.sm,
          ),
          const SizedBox(width: TofuTokens.space3),
          IconButton(
            tooltip: '削除',
            icon: const Icon(Icons.close, size: 20),
            color: TofuTokens.textTertiary,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    this.large = false,
  });
  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: TofuTextStyles.bodyMd.copyWith(color: TofuTokens.textTertiary),
        ),
        const Spacer(),
        Text(
          value,
          style: large ? TofuTextStyles.h2 : TofuTextStyles.bodyLgBold,
        ),
      ],
    );
  }
}
