import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/alert_banner.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/page_title.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../core/ui/tofu_chip.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../providers/sync_providers.dart';
import '../notifiers/checkout_session.dart';
import '../notifiers/regi_providers.dart';
import '../widgets/cart_panel.dart';
import '../widgets/product_button.dart';

/// 商品選択 + カート画面（仕様書 §6.1.2 / §9.2、Figma `03-Register-Products`）。
///
/// レイアウト軸:
/// - landscape (>= 720dp, Figma 1024×768): 左 ProductArea (sync banner +
///   カテゴリタブ + 商品グリッド) と 右 Cart panel (幅 384dp)
/// - portrait (< 720dp, Figma 375×812): 上から Header / カテゴリタブ /
///   商品グリッド / 合計サマリ + 会計ボタン。カート詳細はボトムシート。
///
/// 既存業務ロジック (`CheckoutSessionNotifier` / `appRouterProvider`) は
/// 触らず、表示構造のみ Figma 準拠に再構築している。
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
    final SyncWarningLevel syncLevel =
        ref.watch(syncWarningProvider).value ?? SyncWarningLevel.ok;

    return LayoutBuilder(
      builder: (c, constraints) {
        final bool isWide = constraints.maxWidth >= 720;
        return Scaffold(
          backgroundColor: TofuTokens.bgCanvas,
          appBar: AppHeader(
            title: 'レジ',
            upcomingTicket: ref.watch(upcomingTicketProvider).value,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
              tooltip: '戻る',
            ),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const PageTitle(title: '商品選択'),
                Expanded(
                  child: products.when(
              data: (data) {
                void handleAdd(Product p) {
                  unawaited(HapticFeedback.selectionClick());
                  notifier.addProduct(
                    p,
                    maxStock: flags.stockManagement ? p.stock : null,
                  );
                  _flashHighlight(p.id);
                }

                void handleDecrement(Product p) {
                  unawaited(HapticFeedback.selectionClick());
                  notifier.addProduct(p, delta: -1);
                  _flashHighlight(p.id);
                }

                return isWide
                    ? _LandscapeBody(
                        products: data,
                        session: session,
                        notifier: notifier,
                        stockEnabled: flags.stockManagement,
                        recentlyChangedId: _recentlyChangedId,
                        syncLevel: syncLevel,
                        onAdd: handleAdd,
                        onDecrement: handleDecrement,
                      )
                    : _PortraitBody(
                        products: data,
                        session: session,
                        notifier: notifier,
                        stockEnabled: flags.stockManagement,
                        recentlyChangedId: _recentlyChangedId,
                        syncLevel: syncLevel,
                        onAdd: handleAdd,
                        onDecrement: handleDecrement,
                      );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: '$e'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// landscape (>= 720dp) 用ボディ。Figma `46:21` (HORIZONTAL) を踏襲。
///
/// 左: ProductArea (sync banner + カテゴリタブ + 商品グリッド)
/// 右: 384dp 固定の `CartPanel` (Figma `Cart`: 384x687)。
class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.products,
    required this.session,
    required this.notifier,
    required this.stockEnabled,
    required this.recentlyChangedId,
    required this.syncLevel,
    required this.onAdd,
    required this.onDecrement,
  });

  final List<Product> products;
  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final bool stockEnabled;
  final String? recentlyChangedId;
  final SyncWarningLevel syncLevel;
  final ValueChanged<Product> onAdd;
  final ValueChanged<Product> onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: _ProductArea(
            products: products,
            session: session,
            stockEnabled: stockEnabled,
            syncLevel: syncLevel,
            onAdd: onAdd,
            onDecrement: onDecrement,
            compact: false,
          ),
        ),
        SizedBox(
          width: 384,
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

/// portrait (< 720dp) 用ボディ。Figma `436:492` を踏襲。
class _PortraitBody extends StatelessWidget {
  const _PortraitBody({
    required this.products,
    required this.session,
    required this.notifier,
    required this.stockEnabled,
    required this.recentlyChangedId,
    required this.syncLevel,
    required this.onAdd,
    required this.onDecrement,
  });

  final List<Product> products;
  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final bool stockEnabled;
  final String? recentlyChangedId;
  final SyncWarningLevel syncLevel;
  final ValueChanged<Product> onAdd;
  final ValueChanged<Product> onDecrement;

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
    final int totalQty =
        session.items.fold<int>(0, (s, it) => s + it.quantity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: _ProductArea(
            products: products,
            session: session,
            stockEnabled: stockEnabled,
            syncLevel: syncLevel,
            onAdd: onAdd,
            onDecrement: onDecrement,
            compact: true,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space4,
          ),
          decoration: const BoxDecoration(
            color: TofuTokens.bgCanvas,
            border: Border(top: BorderSide(color: TofuTokens.borderSubtle)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'カート ${session.items.length}点 / $totalQty個',
                      style: TofuTextStyles.bodySmBold.copyWith(
                        color: TofuTokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      TofuFormat.yen(session.totalPrice),
                      style: TofuTextStyles.h2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TofuTokens.space4),
              TofuButton(
                label: 'カート',
                icon: Icons.shopping_cart,
                size: TofuButtonSize.lg,
                onPressed: session.items.isEmpty
                    ? null
                    : () => _showCartSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 商品グリッドと付帯要素 (同期警告バナー + カテゴリタブ) をまとめる領域。
///
/// Figma `46:22` (landscape ProductArea) / `85:40 + 85:49` (portrait) を統合。
class _ProductArea extends StatefulWidget {
  const _ProductArea({
    required this.products,
    required this.session,
    required this.stockEnabled,
    required this.syncLevel,
    required this.onAdd,
    required this.onDecrement,
    required this.compact,
  });

  final List<Product> products;
  final CheckoutSession session;
  final bool stockEnabled;
  final SyncWarningLevel syncLevel;
  final ValueChanged<Product> onAdd;
  final ValueChanged<Product> onDecrement;
  final bool compact;

  @override
  State<_ProductArea> createState() => _ProductAreaState();
}

class _ProductAreaState extends State<_ProductArea> {
  /// Figma `03-Register-Products` のカテゴリ chip 行
  /// (`47:7` → `すべて / 主食 / 飲み物 / デザート`) を視覚的に再現する。
  ///
  /// 注意: `Product` 実体には現状 `category` フィールドが存在しないため、
  /// chip タップによる絞り込みは実装していない（`すべて` 相当の挙動に固定）。
  /// Phase 6 以降で `Product.category` を導入する際にここで分岐させる予定。
  int _selectedIndex = 0;
  static const List<String> _categoryLabels = <String>[
    'すべて',
    '主食',
    '飲み物',
    'デザート',
  ];

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = widget.compact
        ? const EdgeInsets.fromLTRB(
            TofuTokens.space5,
            TofuTokens.space4,
            TofuTokens.space5,
            TofuTokens.space3,
          )
        : const EdgeInsets.fromLTRB(
            TofuTokens.space7,
            TofuTokens.space5,
            TofuTokens.space7,
            TofuTokens.space4,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.syncLevel == SyncWarningLevel.prolongedFailure)
          Padding(
            padding: EdgeInsets.fromLTRB(
              pad.left,
              pad.top,
              pad.right,
              TofuTokens.space3,
            ),
            child: const AlertBanner(
              variant: AlertBannerVariant.warning,
              title: 'クラウド同期失敗',
              message: '長時間同期できていません。営業は継続できますが復旧を確認してください。',
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            pad.left,
            widget.syncLevel == SyncWarningLevel.prolongedFailure
                ? 0
                : pad.top,
            pad.right,
            TofuTokens.space3,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < _categoryLabels.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: TofuTokens.space3),
                  TofuChip(
                    label: _categoryLabels[i],
                    selected: _selectedIndex == i,
                    onTap: () => setState(() => _selectedIndex = i),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: _ProductGrid(
            products: widget.products,
            session: widget.session,
            stockEnabled: widget.stockEnabled,
            onAdd: widget.onAdd,
            onDecrement: widget.onDecrement,
            padding: EdgeInsets.fromLTRB(
              pad.left,
              0,
              pad.right,
              pad.bottom,
            ),
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
    required this.onDecrement,
    required this.padding,
  });

  final List<Product> products;
  final CheckoutSession session;
  final bool stockEnabled;
  final ValueChanged<Product> onAdd;
  final ValueChanged<Product> onDecrement;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return _EmptyState();
    }
    return LayoutBuilder(
      builder: (c, constraints) {
        final int cols = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 700
            ? 3
            : constraints.maxWidth >= 480
            ? 3
            : 2;
        return GridView.builder(
          padding: padding,
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: TofuTokens.space3,
            crossAxisSpacing: TofuTokens.space3,
            childAspectRatio: 1.42,
          ),
          itemBuilder: (c, i) {
            final Product p = products[i];
            final int qty = session.countOf(p.id);
            return ProductButton(
              product: p,
              cartCount: qty,
              stockEnabled: stockEnabled,
              onTap: () => onAdd(p),
              onLongPress: () => onAdd(p),
              onIncrement: qty > 0 ? () => onAdd(p) : null,
              onDecrement: qty > 0 ? () => onDecrement(p) : null,
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
