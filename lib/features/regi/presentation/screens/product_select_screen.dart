import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../providers/settings_providers.dart';
import '../notifiers/checkout_session.dart';
import '../notifiers/regi_providers.dart';
import '../widgets/cart_panel.dart';
import '../widgets/product_button.dart';

/// 商品選択 + カート画面（仕様書 §6.1.2 / §9.2）。
///
/// レイアウト:
/// - landscape (768px+): 左に商品グリッド、右にカートパネル
/// - portrait : 上に商品グリッド、下にカートサマリ + ボトムシートでカート詳細
class ProductSelectScreen extends ConsumerStatefulWidget {
  const ProductSelectScreen({super.key});

  @override
  ConsumerState<ProductSelectScreen> createState() =>
      _ProductSelectScreenState();
}

class _ProductSelectScreenState extends ConsumerState<ProductSelectScreen> {
  String? _recentlyChangedId;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _flashHighlight(String productId) {
    setState(() => _recentlyChangedId = productId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _recentlyChangedId = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Product>> products = ref.watch(
      activeProductsProvider,
    );
    final FeatureFlags flags =
        ref.watch(featureFlagsProvider).value ?? FeatureFlags.allOff;
    final CheckoutSession session = ref.watch(checkoutSessionProvider);
    final CheckoutSessionNotifier notifier = ref.read(
      checkoutSessionProvider.notifier,
    );

    return LayoutBuilder(
      builder: (c, constraints) {
        final bool wide = constraints.maxWidth >= 768;
        return Scaffold(
          backgroundColor: TofuTokens.bgCanvas,
          appBar: AppHeader(
            title: '商品選択',
            upcomingTicket: ref.watch(upcomingTicketProvider).value,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
              tooltip: '戻る',
            ),
          ),
          body: SafeArea(
            child: products.when(
              data: (data) => wide
                  ? _LandscapeBody(
                      products: data,
                      session: session,
                      notifier: notifier,
                      stockEnabled: flags.stockManagement,
                      recentlyChangedId: _recentlyChangedId,
                      onAdd: (p) {
                        unawaited(HapticFeedback.selectionClick());
                        notifier.addProduct(
                          p,
                          maxStock: flags.stockManagement ? p.stock : null,
                        );
                        _flashHighlight(p.id);
                      },
                    )
                  : _PortraitBody(
                      products: data,
                      session: session,
                      notifier: notifier,
                      stockEnabled: flags.stockManagement,
                      recentlyChangedId: _recentlyChangedId,
                      onAdd: (p) {
                        unawaited(HapticFeedback.selectionClick());
                        notifier.addProduct(
                          p,
                          maxStock: flags.stockManagement ? p.stock : null,
                        );
                        _flashHighlight(p.id);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: '$e'),
            ),
          ),
        );
      },
    );
  }
}

class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.products,
    required this.session,
    required this.notifier,
    required this.stockEnabled,
    required this.recentlyChangedId,
    required this.onAdd,
  });

  final List<Product> products;
  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final bool stockEnabled;
  final String? recentlyChangedId;
  final ValueChanged<Product> onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: _ProductGrid(
            products: products,
            session: session,
            stockEnabled: stockEnabled,
            onAdd: onAdd,
          ),
        ),
        SizedBox(
          width: 380,
          child: CartPanel(
            session: session,
            notifier: notifier,
            products: products,
            stockEnabled: stockEnabled,
            recentlyChangedId: recentlyChangedId,
            onCheckout: () => context.push('/regi/checkout'),
          ),
        ),
      ],
    );
  }
}

class _PortraitBody extends StatelessWidget {
  const _PortraitBody({
    required this.products,
    required this.session,
    required this.notifier,
    required this.stockEnabled,
    required this.recentlyChangedId,
    required this.onAdd,
  });

  final List<Product> products;
  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final bool stockEnabled;
  final String? recentlyChangedId;
  final ValueChanged<Product> onAdd;

  void _showCartSheet(BuildContext context) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (c2, _) => Container(
          decoration: const BoxDecoration(
            color: TofuTokens.bgCanvas,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(TofuTokens.radiusXl),
            ),
          ),
          child: CartPanel(
            session: session,
            notifier: notifier,
            products: products,
            stockEnabled: stockEnabled,
            recentlyChangedId: recentlyChangedId,
            onCheckout: () {
              Navigator.of(c2).pop();
              unawaited(context.push('/regi/checkout'));
            },
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _ProductGrid(
            products: products,
            session: session,
            stockEnabled: stockEnabled,
            onAdd: onAdd,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(TofuTokens.space5),
          decoration: const BoxDecoration(
            color: TofuTokens.bgCanvas,
            border: Border(top: BorderSide(color: TofuTokens.borderSubtle)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${session.items.length}点 / '
                      '${session.items.fold<int>(0, (s, it) => s + it.quantity)}個',
                      style: TofuTextStyles.bodySmBold.copyWith(
                        color: TofuTokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '¥${session.totalPrice.yen}',
                      style: TofuTextStyles.h2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TofuTokens.space5),
              FilledButton.icon(
                onPressed: () => _showCartSheet(context),
                icon: const Icon(Icons.shopping_cart),
                label: const Text('カート'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, TofuTokens.touchPrimary),
                  backgroundColor: TofuTokens.brandPrimary,
                  foregroundColor: TofuTokens.brandOnPrimary,
                  textStyle: TofuTextStyles.bodyLgBold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.session,
    required this.stockEnabled,
    required this.onAdd,
  });

  final List<Product> products;
  final CheckoutSession session;
  final bool stockEnabled;
  final ValueChanged<Product> onAdd;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return _EmptyState();
    }
    return LayoutBuilder(
      builder: (c, constraints) {
        final int cols = constraints.maxWidth >= 1200
            ? 5
            : constraints.maxWidth >= 800
            ? 4
            : constraints.maxWidth >= 500
            ? 3
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(TofuTokens.space5),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: TofuTokens.space4,
            crossAxisSpacing: TofuTokens.space4,
            childAspectRatio: 1.4,
          ),
          itemBuilder: (c, i) {
            final Product p = products[i];
            return ProductButton(
              product: p,
              cartCount: session.countOf(p.id),
              stockEnabled: stockEnabled,
              onTap: () => onAdd(p),
              onLongPress: () => onAdd(p),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TofuTokens.space7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: TofuTokens.textDisabled,
            ),
            const SizedBox(height: TofuTokens.space5),
            Text(
              '商品が登録されていません',
              style: TofuTextStyles.h3.copyWith(color: TofuTokens.textTertiary),
            ),
            const SizedBox(height: TofuTokens.space3),
            Text(
              '設定 → 商品マスタ から商品を登録してください',
              style: TofuTextStyles.bodyMd.copyWith(
                color: TofuTokens.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TofuTokens.space7),
        child: StatusIndicator.custom(
          label: '商品の読み込みに失敗: $message',
          icon: Icons.error_outline,
          tone: StatusIndicatorTone.danger,
        ),
      ),
    );
  }
}
