import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/format.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/product.dart';
import '../notifiers/checkout_session.dart';

/// カートパネル（仕様書 §9.2 / Figma `03-Register-Products` → `Cart`）。
///
/// Figma 構造 (`46:23`, 384x687):
/// - ヘッダ (`47:62`, 88h): 「カート」H4 + 右側に「直前取消」テキストリンク
///   と「クリア」ボタン。
/// - リスト (`47:66`): `CartRow` (`商品名 / × N / 価格`) を縦に並べる。
/// - フッタ (`47:79`, 188h): 「合計」caption + 大きな数字 + 「会計へ進む →」
///   プライマリ大ボタン。
///
/// `notifier.undoLast()` は末尾エントリを 1 件分ロールバックする純粋な
/// state 操作（[CheckoutSessionNotifier.undoLast] を参照）。
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

  @override
  Widget build(BuildContext context) {
    final bool hasItems = session.items.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: TofuTokens.bgCanvas,
        border: Border(left: BorderSide(color: TofuTokens.borderSubtle)),
      ),
      child: Column(
        children: <Widget>[
          _CartHeader(
            hasItems: hasItems,
            onUndo: notifier.undoLast,
            onClear: notifier.clearItems,
          ),
          const Divider(height: 1, color: TofuTokens.borderSubtle),
          Expanded(
            child: hasItems
                ? ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: TofuTokens.space2,
                    ),
                    itemCount: session.items.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: TofuTokens.borderSubtle,
                    ),
                    itemBuilder: (c, i) {
                      final OrderItem it = session.items[i];
                      return _CartRow(
                            key: ValueKey<String>('cart-row-${it.productId}'),
                            item: it,
                            highlighted: recentlyChangedId == it.productId,
                          )
                          .animate()
                          .fadeIn(
                            duration: TofuTokens.motionShort,
                          )
                          .slideX(
                            begin: 0.08,
                            end: 0,
                            duration: TofuTokens.motionMedium,
                            curve: Curves.easeOutCubic,
                          );
                    },
                  )
                : const _EmptyCart(),
          ),
          const Divider(height: 1, color: TofuTokens.borderSubtle),
          _CartFooter(
            total: TofuFormat.yen(session.totalPrice),
            enabled: hasItems,
            onCheckout: onCheckout,
          ),
        ],
      ),
    );
  }
}

/// カートヘッダ。Figma `47:62` を踏襲（カート + 直前取消 link + クリア link）。
class _CartHeader extends StatelessWidget {
  const _CartHeader({
    required this.hasItems,
    required this.onUndo,
    required this.onClear,
  });

  final bool hasItems;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space5,
      ),
      child: Row(
        children: <Widget>[
          const Text('カート', style: TofuTextStyles.h4),
          const Spacer(),
          _TextLink(
            label: '直前取消',
            onPressed: hasItems ? onUndo : null,
          ),
          const SizedBox(width: TofuTokens.space5),
          _TextLink(
            label: 'クリア',
            onPressed: hasItems ? onClear : null,
          ),
        ],
      ),
    );
  }
}

/// Figma の「直前取消 / クリア」（テキストリンク見た目）。
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = onPressed == null
        ? TofuTokens.textDisabled
        : TofuTokens.textLink;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(TofuTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space2,
          vertical: TofuTokens.space2,
        ),
        child: Text(
          label,
          style: TofuTextStyles.bodyMdBold.copyWith(color: color),
        ),
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

/// Figma `CartRow` (`426:481` 等) を踏襲。
/// 3 列: `商品名` / `× N` / `金額(小計)`。
class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.highlighted,
    super.key,
  });

  final OrderItem item;
  final bool highlighted;

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
            child: Text(
              item.productName,
              style: TofuTextStyles.bodyLgBold,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: TofuTokens.space3),
          SizedBox(
            width: 48,
            child: Text(
              '× ${item.quantity}',
              style: TofuTextStyles.numberMd.copyWith(
                color: TofuTokens.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: TofuTokens.space3),
          Text(
            TofuFormat.yen(item.subtotal),
            style: TofuTextStyles.numberMd,
          ),
        ],
      ),
    );
  }
}

/// Figma `47:79` (合計 + 会計へ進む)。
class _CartFooter extends StatelessWidget {
  const _CartFooter({
    required this.total,
    required this.enabled,
    required this.onCheckout,
  });

  final String total;
  final bool enabled;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TofuTokens.space5,
        TofuTokens.space5,
        TofuTokens.space5,
        TofuTokens.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '合計',
                  style: TofuTextStyles.caption.copyWith(
                    color: TofuTokens.textTertiary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                total,
                style: TofuTextStyles.h1,
              ),
            ],
          ),
          const SizedBox(height: TofuTokens.space5),
          FilledButton.icon(
            onPressed: enabled ? onCheckout : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('会計へ進む'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                TofuTokens.touchPrimary,
              ),
              backgroundColor: TofuTokens.brandPrimary,
              foregroundColor: TofuTokens.brandOnPrimary,
              disabledBackgroundColor: TofuTokens.gray200,
              disabledForegroundColor: TofuTokens.textDisabled,
              textStyle: TofuTextStyles.bodyLgBold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
