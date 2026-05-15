import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/alert_banner.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/kitchen_order.dart';
import '../../../../domain/enums/kitchen_status.dart';
import '../../domain/kitchen_alert.dart';
import '../../domain/mark_served_usecase.dart';
import '../notifiers/kitchen_providers.dart';

/// キッチン画面（仕様書 §6.2 / §9.4 / Figma `07-Kitchen-Home`）。
///
/// Figma レイアウト:
///   - landscape (id 436:503, 1024×768): 左ペイン「未調理」(620w) + 右ペイン
///     「提供済」(404w, bgSurface tinted)。Horizontal 2 カラム。
///   - portrait  (id 436:504, 375×812):  Header + TabBar + 縦リスト。
///
/// 業務要件:
///   - `kitchenOrdersProvider` を購読し、pending / done / cancelled を分離
///   - `MarkServedUseCase.execute/undo` で提供完了 / 取消し
///   - `kitchenAlertsProvider` を購読し、取消通知時に AlertBanner を表示
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
            unawaited(HapticFeedback.heavyImpact());
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
      appBar: const AppHeader(title: 'キッチン'),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            if (_activeAlert != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TofuTokens.space5,
                  TofuTokens.space4,
                  TofuTokens.space5,
                  0,
                ),
                child: AlertBanner(
                  variant: AlertBannerVariant.danger,
                  title: '注文取消（整理券 ${_activeAlert!.ticketNumber}）',
                  message: _alertMessage(_activeAlert!),
                  actionLabel: '了解',
                  onAction: () => setState(() => _activeAlert = null),
                  onClose: () => setState(() => _activeAlert = null),
                ),
              ),
            Expanded(
              child: orders.when(
                data: (all) => _buildBody(context, all),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: StatusIndicator.custom(
                    label: '注文の取得に失敗: $e',
                    icon: Icons.error_outline,
                    tone: StatusIndicatorTone.danger,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _alertMessage(KitchenAlert alert) {
    final String wasLabel = switch (alert.previousStatus) {
      KitchenStatus.done => '提供完了済',
      _ => '調理中',
    };
    return '$wasLabel の注文がレジで取消されました。現物の処分が必要です。';
  }

  Widget _buildBody(BuildContext context, List<KitchenOrder> all) {
    final List<KitchenOrder> pending = all
        .where((o) => o.status == KitchenStatus.pending)
        .toList();
    // Figma 「提供済」(右ペイン): 直近を上から、cancelled も含む。
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

    return LayoutBuilder(
      builder: (c, constraints) {
        final bool wide = constraints.maxWidth >= 720;
        if (wide) {
          // Figma landscape (436:503): 左右 2 ペイン構成。
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 620,
                child: _PendingPane(
                  orders: pending,
                  onAction: _markServed,
                ),
              ),
              Expanded(
                flex: 404,
                child: _ServedPane(orders: done),
              ),
            ],
          );
        }
        // Figma portrait (436:504): タブで pending / done を切替。
        return Column(
          children: <Widget>[
            Material(
              color: TofuTokens.bgCanvas,
              child: TabBar(
                controller: _tab,
                labelColor: TofuTokens.brandPrimary,
                unselectedLabelColor: TofuTokens.textTertiary,
                indicatorColor: TofuTokens.brandPrimary,
                tabs: <Tab>[
                  Tab(text: '未調理 (${pending.length})'),
                  Tab(text: '提供済 (${done.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: <Widget>[
                  _PendingPane(
                    orders: pending,
                    onAction: _markServed,
                    isPortrait: true,
                  ),
                  _ServedPane(orders: done, isPortrait: true),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pending pane (Figma 73:82): 「未調理 / 5件」+ 横並び OrderCard グリッド
// ---------------------------------------------------------------------------
class _PendingPane extends StatelessWidget {
  const _PendingPane({
    required this.orders,
    required this.onAction,
    this.isPortrait = false,
  });

  final List<KitchenOrder> orders;
  final Future<void> Function(int orderId) onAction;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TofuTokens.bgCanvas,
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space6,
        vertical: TofuTokens.space7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!isPortrait)
            _PaneTitle(
              title: '未調理',
              count: orders.length,
              accent: TofuTokens.brandPrimary,
            ),
          if (!isPortrait) const SizedBox(height: TofuTokens.space4),
          Expanded(
            child: orders.isEmpty
                ? const _EmptyState(
                    label: '未調理の注文はありません',
                    icon: Icons.check_circle_outline,
                  )
                : LayoutBuilder(
                    builder: (c, constraints) {
                      // Figma: 280w カード横並び。可能な列数で詰める。
                      final int cols = (constraints.maxWidth / 296)
                          .floor()
                          .clamp(1, 4);
                      return GridView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: orders.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: TofuTokens.space4,
                          crossAxisSpacing: TofuTokens.space4,
                          childAspectRatio: 280 / 220,
                        ),
                        itemBuilder: (c, i) => _PendingCard(
                          order: orders[i],
                          onAction: () => onAction(orders[i].orderId),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Served pane (Figma 73:155): bgSurface 背景 + 縦リスト 356×96 のミニカード
// ---------------------------------------------------------------------------
class _ServedPane extends StatelessWidget {
  const _ServedPane({required this.orders, this.isPortrait = false});

  final List<KitchenOrder> orders;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TofuTokens.bgSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space6,
        vertical: TofuTokens.space7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!isPortrait)
            _PaneTitle(
              title: '提供済',
              subtitle: '直近 / ${orders.length}件',
              accent: TofuTokens.textTertiary,
            ),
          if (!isPortrait) const SizedBox(height: TofuTokens.space4),
          Expanded(
            child: orders.isEmpty
                ? const _EmptyState(
                    label: '提供済の履歴はまだありません',
                    icon: Icons.history,
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: orders.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: TofuTokens.space3),
                    itemBuilder: (c, i) => _ServedCard(order: orders[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pane title (Figma 73:83 / 73:156): ラベル + 件数 (補足テキスト)
// ---------------------------------------------------------------------------
class _PaneTitle extends StatelessWidget {
  const _PaneTitle({
    required this.title,
    required this.accent,
    this.count,
    this.subtitle,
  });
  final String title;
  final Color accent;
  final int? count;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: TofuTokens.space3),
        Text(title, style: TofuTextStyles.h4),
        const SizedBox(width: TofuTokens.space3),
        if (count != null)
          Text(
            '${count!}件',
            style: TofuTextStyles.bodySmBold.copyWith(
              color: TofuTokens.textTertiary,
            ),
          ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TofuTextStyles.bodySm.copyWith(
              color: TofuTokens.textTertiary,
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 64, color: TofuTokens.textDisabled),
          const SizedBox(height: TofuTokens.space5),
          Text(
            label,
            style: TofuTextStyles.h4.copyWith(color: TofuTokens.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending card (Figma 73:87, 280×208): bgSurface + brandPrimary 太枠
//   - 整理券番号 + 経過時間
//   - 注文行リスト
//   - 「提供完了」ボタン
// ---------------------------------------------------------------------------
class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.order, required this.onAction});
  final KitchenOrder order;
  final VoidCallback onAction;

  List<({String name, int qty})> _parseItems() {
    try {
      final dynamic raw = jsonDecode(order.itemsJson);
      if (raw is! List) {
        return <({String name, int qty})>[];
      }
      final List<({String name, int qty})> out = <({String name, int qty})>[];
      for (final dynamic e in raw) {
        if (e is! Map<String, dynamic>) continue;
        out.add((
          name: e['name']?.toString() ?? '',
          qty:
              (e['quantity'] as num?)?.toInt() ??
              (e['qty'] as num?)?.toInt() ??
              0,
        ));
      }
      return out;
    } catch (e, st) {
      AppLogger.w(
        'KitchenOrder.itemsJson parse failed (order=${order.orderId})',
        error: e,
        stackTrace: st,
      );
      return <({String name, int qty})>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCancelled = order.status == KitchenStatus.cancelled;
    final List<({String name, int qty})> items = _parseItems();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space4,
      ),
      decoration: BoxDecoration(
        color: isCancelled ? TofuTokens.dangerBg : TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(
          color: isCancelled
              ? TofuTokens.dangerBorder
              : TofuTokens.brandPrimary,
          width: TofuTokens.strokeThick,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                order.ticketNumber.toString(),
                style: TofuTextStyles.numberLg.copyWith(
                  color: isCancelled
                      ? TofuTokens.dangerText
                      : TofuTokens.brandPrimary,
                ),
              ),
              const Spacer(),
              Text(
                TofuFormat.relativeFromNow(order.receivedAt),
                style: TofuTextStyles.bodySmBold.copyWith(
                  color: TofuTokens.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: TofuTokens.space3),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                if (isCancelled)
                  const Padding(
                    padding: EdgeInsets.only(bottom: TofuTokens.space2),
                    child: StatusIndicator.custom(
                      label: '取消',
                      icon: Icons.block,
                      tone: StatusIndicatorTone.danger,
                      dense: true,
                    ),
                  ),
                for (final ({String name, int qty}) it in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            it.name,
                            style: TofuTextStyles.bodyMd,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('×${it.qty}', style: TofuTextStyles.bodyMdBold),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!isCancelled) ...<Widget>[
            const SizedBox(height: TofuTokens.space3),
            TofuButton(
              label: '提供完了',
              icon: Icons.done_all,
              size: TofuButtonSize.lg,
              fullWidth: true,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Served card (Figma 73:160, 356×96): 縦リストのコンパクト表示
// ---------------------------------------------------------------------------
class _ServedCard extends StatelessWidget {
  const _ServedCard({required this.order});
  final KitchenOrder order;

  @override
  Widget build(BuildContext context) {
    final bool isCancelled = order.status == KitchenStatus.cancelled;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space4,
      ),
      decoration: BoxDecoration(
        color: isCancelled ? TofuTokens.dangerBg : TofuTokens.bgCanvas,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(
          color: isCancelled
              ? TofuTokens.dangerBorder
              : TofuTokens.borderSubtle,
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            order.ticketNumber.toString(),
            style: TofuTextStyles.numberMd.copyWith(
              color: isCancelled
                  ? TofuTokens.dangerText
                  : TofuTokens.textPrimary,
            ),
          ),
          const SizedBox(width: TofuTokens.space4),
          if (isCancelled)
            const StatusIndicator.custom(
              label: '取消',
              icon: Icons.block,
              tone: StatusIndicatorTone.danger,
              dense: true,
            )
          else
            const StatusIndicator.custom(
              label: '提供済',
              icon: Icons.check_circle,
              tone: StatusIndicatorTone.success,
              dense: true,
            ),
          const Spacer(),
          Text(
            TofuFormat.relativeFromNow(order.receivedAt),
            style: TofuTextStyles.bodySm.copyWith(
              color: TofuTokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
