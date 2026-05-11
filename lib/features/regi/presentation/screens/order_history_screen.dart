import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exceptions.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/confirm_dialog.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/status_chip.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/enums/sync_status.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../providers/usecase_providers.dart';
import '../../../regi/domain/cancel_order_flow_usecase.dart';
import '../notifiers/regi_providers.dart';

/// 注文履歴 + 取消画面（仕様書 §6.6）。
class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  bool _showCancelled = true;

  Future<void> _cancel(Order order) async {
    final bool ok = await TofuConfirmDialog.show(
      context,
      title: '注文を取消しますか?',
      message:
          '整理券 ${order.ticketNumber} / ${TofuFormat.yen(order.finalPrice)}\n\n'
          '在庫・整理券・キッチン/呼び出し連携への通知を不可分に巻き戻します。'
          '操作はログに記録され、後から振り返れます。',
      confirmLabel: '取消する',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok) {
      return;
    }
    final FeatureFlags flags =
        ref.read(featureFlagsProvider).value ?? FeatureFlags.allOff;
    final CancelOrderFlowUseCase? flow = await ref.read(
      cancelOrderFlowUseCaseProvider.future,
    );
    if (flow == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('店舗IDが未設定です')));
      return;
    }
    try {
      await flow.execute(
        orderId: order.id,
        flags: flags,
        // 履歴経由の取消では金種差分を保持していないため空にして渡す。
        // 金種管理オン時は別途レジ締めで実測値と理論値を照合する運用前提（仕様書 §6.4）。
        originalCashDelta: const <int, int>{},
      );
      ref.invalidate(ticketPoolProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('整理券 ${order.ticketNumber} を取消しました')),
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
    final AsyncValue<List<Order>> orders = ref.watch(orderHistoryProvider);

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppBar(
        title: const Text('注文履歴'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: _showCancelled ? '取消済みを隠す' : '取消済みを表示',
            icon: Icon(
              _showCancelled ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () => setState(() => _showCancelled = !_showCancelled),
          ),
        ],
      ),
      body: SafeArea(
        child: orders.when(
          data: (all) {
            final List<Order> visible = _showCancelled
                ? all
                : all.where((o) => !o.isCancelled).toList();
            if (visible.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.history,
                      size: 64,
                      color: TofuTokens.textDisabled,
                    ),
                    const SizedBox(height: TofuTokens.space5),
                    Text(
                      '注文はまだありません',
                      style: TofuTextStyles.h4.copyWith(
                        color: TofuTokens.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(TofuTokens.space5),
              itemCount: visible.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: TofuTokens.space3),
              itemBuilder: (c, i) =>
                  _HistoryRow(order: visible[i], onCancel: _cancel),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: StatusChip(
              label: '注文の取得に失敗: $e',
              icon: Icons.error_outline,
              tone: TofuStatusTone.danger,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.order, required this.onCancel});
  final Order order;
  final Future<void> Function(Order) onCancel;

  @override
  Widget build(BuildContext context) {
    final bool cancelled = order.isCancelled;
    final List<Widget> chips = <Widget>[];

    chips.add(
      StatusChip(
        label: switch (order.orderStatus) {
          OrderStatus.unsent => '未送信',
          OrderStatus.sent => '送信済',
          OrderStatus.served => '提供済',
          OrderStatus.cancelled => '取消済',
        },
        icon: switch (order.orderStatus) {
          OrderStatus.unsent => Icons.outbox,
          OrderStatus.sent => Icons.send,
          OrderStatus.served => Icons.check_circle,
          OrderStatus.cancelled => Icons.cancel,
        },
        tone: switch (order.orderStatus) {
          OrderStatus.unsent => TofuStatusTone.warning,
          OrderStatus.sent => TofuStatusTone.info,
          OrderStatus.served => TofuStatusTone.success,
          OrderStatus.cancelled => TofuStatusTone.danger,
        },
        dense: true,
      ),
    );
    if (order.syncStatus == SyncStatus.notSynced) {
      chips.add(const SizedBox(width: TofuTokens.space2));
      chips.add(
        const StatusChip(
          label: '未同期',
          icon: Icons.cloud_off,
          tone: TofuStatusTone.warning,
          dense: true,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        color: cancelled ? TofuTokens.gray100 : TofuTokens.bgCanvas,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: TofuTokens.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: TofuTokens.space3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cancelled
                  ? TofuTokens.gray300
                  : TofuTokens.brandPrimarySubtle,
              borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  '整理券',
                  style: TofuTextStyles.captionBold.copyWith(
                    color: TofuTokens.textTertiary,
                  ),
                ),
                Text(
                  order.ticketNumber.toString(),
                  style: TofuTextStyles.numberLg,
                ),
              ],
            ),
          ),
          const SizedBox(width: TofuTokens.space5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '#${order.id} ・ ${TofuFormat.mmddhhmm(order.createdAt)}',
                  style: TofuTextStyles.bodySmBold.copyWith(
                    color: TofuTokens.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.items
                      .map((it) => '${it.productName}×${it.quantity}')
                      .join(' / '),
                  style: TofuTextStyles.bodyMd.copyWith(
                    decoration: cancelled
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: TofuTokens.space3),
                Wrap(children: chips),
              ],
            ),
          ),
          const SizedBox(width: TofuTokens.space5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                TofuFormat.yen(order.finalPrice),
                style: TofuTextStyles.h3.copyWith(
                  decoration: cancelled
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  color: cancelled
                      ? TofuTokens.textTertiary
                      : TofuTokens.textPrimary,
                ),
              ),
              const SizedBox(height: TofuTokens.space2),
              if (!cancelled)
                TofuButton(
                  label: '取消',
                  icon: Icons.delete_outline,
                  variant: TofuButtonVariant.outlined,
                  onPressed: () => onCancel(order),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
