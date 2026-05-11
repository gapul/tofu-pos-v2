import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exceptions.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/status_chip.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/kitchen_order.dart';
import '../../../../domain/enums/kitchen_status.dart';
import '../../domain/kitchen_alert.dart';
import '../../domain/mark_served_usecase.dart';
import '../notifiers/kitchen_providers.dart';

/// キッチン画面（仕様書 §6.2 / §9.4）。
///
/// - 未調理 / 提供完了の双方を同一画面で参照できる（タブ）
/// - 「提供完了」直後は Undo SnackBar を出す
/// - 取消通知（cancelledMidProcess）受信時は赤背景バナー
class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen>
    with TickerProviderStateMixin {
  late TabController _tab;
  KitchenAlert? _activeAlert;
  ProviderSubscription<AsyncValue<KitchenAlert>>? _alertSub;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alertSub = ref.listenManual<AsyncValue<KitchenAlert>>(
        kitchenAlertsProvider,
        (prev, next) {
          final KitchenAlert? alert = next.value;
          if (alert != null && alert != _activeAlert) {
            HapticFeedback.heavyImpact();
            setState(() => _activeAlert = alert);
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _alertSub?.close();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _markServed(int orderId) async {
    final MarkServedUseCase? uc = await ref.read(
      markServedUseCaseProvider.future,
    );
    if (uc == null) {
      return;
    }
    try {
      await uc.execute(orderId);
      if (!mounted) {
        return;
      }
      unawaited(HapticFeedback.mediumImpact());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('提供完了'),
          action: SnackBarAction(
            label: '取り消し',
            onPressed: () async {
              try {
                await uc.undo(orderId);
              } on AppException catch (e) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } on AppException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: TofuTokens.dangerBgStrong,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<KitchenOrder>> orders = ref.watch(
      kitchenOrdersProvider,
    );

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(tabController: _tab),
            if (_activeAlert != null)
              _AlertBanner(
                alert: _activeAlert!,
                onDismiss: () => setState(() => _activeAlert = null),
              ),
            Expanded(
              child: orders.when(
                data: (all) {
                  final List<KitchenOrder> pending = all
                      .where(
                        (o) => o.status == KitchenStatus.pending,
                      )
                      .toList();
                  final List<KitchenOrder> done = all
                      .where(
                        (o) =>
                            o.status == KitchenStatus.done ||
                            o.status == KitchenStatus.cancelled,
                      )
                      .toList()
                      .reversed
                      .take(50)
                      .toList();
                  return TabBarView(
                    controller: _tab,
                    children: <Widget>[
                      _OrderList(
                        orders: pending,
                        onAction: _markServed,
                        emptyMessage: '未調理の注文はありません',
                        emptyIcon: Icons.check_circle_outline,
                      ),
                      _OrderList(
                        orders: done,
                        onAction: null,
                        emptyMessage: '提供完了の履歴はまだありません',
                        emptyIcon: Icons.history,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => StatusChip(
                  label: '注文の取得に失敗: $e',
                  icon: Icons.error_outline,
                  tone: TofuStatusTone.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tabController});
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TofuTokens.bgCanvas,
        border: Border(bottom: BorderSide(color: TofuTokens.borderSubtle)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TofuTokens.space5,
              TofuTokens.space5,
              TofuTokens.space5,
              TofuTokens.space2,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: TofuTokens.brandPrimary,
                    borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: TofuTokens.brandOnPrimary,
                  ),
                ),
                const SizedBox(width: TofuTokens.space4),
                const Text('キッチン', style: TofuTextStyles.h3),
              ],
            ),
          ),
          TabBar(
            controller: tabController,
            tabs: const <Tab>[
              Tab(icon: Icon(Icons.restaurant_menu), text: '未調理'),
              Tab(icon: Icon(Icons.done_all), text: '提供完了'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alert, required this.onDismiss});
  final KitchenAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final String wasLabel = switch (alert.previousStatus) {
      KitchenStatus.done => '提供完了済',
      _ => '調理中',
    };
    return Container(
      width: double.infinity,
      color: TofuTokens.dangerBgStrong,
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space5,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: TofuTokens.brandOnPrimary,
            size: 32,
          ),
          const SizedBox(width: TofuTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '注文取消（整理券 ${alert.ticketNumber}）',
                  style: TofuTextStyles.h4.copyWith(
                    color: TofuTokens.brandOnPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$wasLabel の注文がレジで取消されました。現物の処分が必要です。',
                  style: TofuTextStyles.bodyMd.copyWith(
                    color: TofuTokens.brandOnPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TofuTokens.space5),
          TofuButton(label: '了解', onPressed: onDismiss),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.onAction,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  final List<KitchenOrder> orders;
  final Future<void> Function(int orderId)? onAction;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(emptyIcon, size: 64, color: TofuTokens.textDisabled),
            const SizedBox(height: TofuTokens.space5),
            Text(
              emptyMessage,
              style: TofuTextStyles.h4.copyWith(color: TofuTokens.textTertiary),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (c, constraints) {
        final int cols = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 800
            ? 3
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(TofuTokens.space5),
          itemCount: orders.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: TofuTokens.space4,
            crossAxisSpacing: TofuTokens.space4,
          ),
          itemBuilder: (c, i) =>
              _OrderCard(order: orders[i], onAction: onAction),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onAction});
  final KitchenOrder order;
  final Future<void> Function(int orderId)? onAction;

  List<({String name, int qty})> _parseItems() {
    try {
      final dynamic raw = jsonDecode(order.itemsJson);
      if (raw is! List) {
        return <({String name, int qty})>[];
      }
      return raw.map<({String name, int qty})>((dynamic e) {
        final Map<String, dynamic> m = e as Map<String, dynamic>;
        return (
          name: m['name']?.toString() ?? '',
          qty:
              (m['quantity'] as num?)?.toInt() ??
              (m['qty'] as num?)?.toInt() ??
              0,
        );
      }).toList();
    } catch (_) {
      return <({String name, int qty})>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = order.status == KitchenStatus.pending;
    final bool isCancelled = order.status == KitchenStatus.cancelled;
    final List<({String name, int qty})> items = _parseItems();

    final Color borderColor = isCancelled
        ? TofuTokens.dangerBorder
        : (isPending ? TofuTokens.brandPrimary : TofuTokens.borderSubtle);

    return Container(
      decoration: BoxDecoration(
        color: isCancelled ? TofuTokens.dangerBg : TofuTokens.bgCanvas,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(
          color: borderColor,
          width: isCancelled ? 2 : TofuTokens.strokeHairline,
        ),
        boxShadow: isPending ? TofuTokens.elevationSm : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TofuTokens.space5,
              vertical: TofuTokens.space4,
            ),
            decoration: BoxDecoration(
              color: isCancelled
                  ? TofuTokens.dangerBgStrong
                  : (isPending
                        ? TofuTokens.brandPrimary
                        : TofuTokens.bgSurface),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(TofuTokens.radiusLg),
                topRight: Radius.circular(TofuTokens.radiusLg),
              ),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  order.ticketNumber.toString(),
                  style: TofuTextStyles.numberLg.copyWith(
                    color: (isPending || isCancelled)
                        ? TofuTokens.brandOnPrimary
                        : TofuTokens.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  TofuFormat.relativeFromNow(order.receivedAt),
                  style: TofuTextStyles.bodySmBold.copyWith(
                    color: (isPending || isCancelled)
                        ? TofuTokens.brandOnPrimary
                        : TofuTokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(TofuTokens.space4),
              child: ListView(
                children: <Widget>[
                  if (isCancelled)
                    const StatusChip(
                      label: '取消',
                      icon: Icons.block,
                      tone: TofuStatusTone.danger,
                    ),
                  for (final ({String name, int qty}) it in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              it.name,
                              style: TofuTextStyles.bodyLg,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('×${it.qty}', style: TofuTextStyles.bodyLgBold),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onAction != null && !isCancelled)
            Padding(
              padding: const EdgeInsets.all(TofuTokens.space4),
              child: TofuButton(
                label: '提供完了',
                icon: Icons.done_all,
                size: TofuButtonSize.primary,
                fullWidth: true,
                onPressed: () => onAction!(order.orderId),
              ),
            ),
        ],
      ),
    );
  }
}
