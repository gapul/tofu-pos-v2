import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exceptions.dart';
import '../../../../core/export/csv_export_file_service.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/confirm_dialog.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/page_title.dart';
import '../../../../core/ui/pane_title.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../core/ui/tofu_chip.dart';
import '../../../../core/ui/tofu_icon.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/enums/sync_status.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../providers/usecase_providers.dart';
import '../../../regi/domain/cancel_order_flow_usecase.dart';
import '../notifiers/regi_providers.dart';

/// 注文履歴 + 取消画面（Figma `11-Register-History` / 仕様書 §6.6）。
///
/// landscape: PaneTitle ヘッダー + CSV書き出しボタン + テーブル風リスト
/// （整理券 / 時刻 / 商品 / 金額 / 状態 / 操作 の 6 カラム）。
class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  bool _showCancelled = true;
  bool _csvBusy = false;

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

  Future<void> _exportCsv() async {
    setState(() => _csvBusy = true);
    try {
      final List<Order> orders = await ref
          .read(orderRepositoryProvider)
          .findAll();
      final shopId =
          (await ref.read(settingsRepositoryProvider).getShopId())?.value ??
          'unknown_shop';
      final String path = await CsvExportFileService().writeAndShare(
        orders: orders,
        shopId: shopId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV を共有しました ($path)')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エクスポートに失敗: $e')));
    } finally {
      if (mounted) {
        setState(() => _csvBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Order>> orders = ref.watch(orderHistoryProvider);

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppHeader(
        title: 'レジ',
        leading: IconButton(
          icon: const TofuIcon(TofuIconName.chevronLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const PageTitle(title: '注文履歴'),
            Expanded(
              child: LayoutBuilder(
          builder: (c, constraints) {
            final bool wide = constraints.maxWidth >= 720;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? TofuTokens.space7 : TofuTokens.space5,
                vertical: TofuTokens.space5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Header(
                    count: orders.value?.length,
                    showCancelled: _showCancelled,
                    onToggleCancelled: () =>
                        setState(() => _showCancelled = !_showCancelled),
                    csvBusy: _csvBusy,
                    onCsv: _exportCsv,
                  ),
                  const SizedBox(height: TofuTokens.space5),
                  Expanded(
                    child: orders.when(
                      data: (all) => _buildList(all, wide: wide),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
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
            );
          },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Order> all, {required bool wide}) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (wide) const _ColumnHeader(),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: visible.length,
            separatorBuilder: (_, _) => const Divider(
              height: TofuTokens.strokeHairline,
              thickness: TofuTokens.strokeHairline,
              color: TofuTokens.borderSubtle,
            ),
            itemBuilder: (c, i) => wide
                ? _HistoryRowWide(order: visible[i], onCancel: _cancel)
                : _HistoryRowNarrow(order: visible[i], onCancel: _cancel),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 上部ヘッダー: PaneTitle (件数) + 表示切替 + CSV書き出し。
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.showCancelled,
    required this.onToggleCancelled,
    required this.csvBusy,
    required this.onCsv,
  });

  final int? count;
  final bool showCancelled;
  final VoidCallback onToggleCancelled;
  final bool csvBusy;
  final VoidCallback onCsv;

  @override
  Widget build(BuildContext context) {
    return PaneTitle(
      title: '注文履歴',
      count: count,
      subtitle: showCancelled ? '取消済みを含む' : '取消済みを除外',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TofuChip(
            label: showCancelled ? '取消を隠す' : '取消を表示',
            selected: showCancelled,
            onTap: onToggleCancelled,
          ),
          const SizedBox(width: TofuTokens.adjacentSpacing),
          TofuButton(
            label: 'CSV書き出し',
            icon: Icons.file_download,
            variant: TofuButtonVariant.secondary,
            loading: csvBusy,
            onPressed: csvBusy ? null : onCsv,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// テーブル列ヘッダー (Figma 81:91): 整理券 / 時刻 / 商品 / 金額 / 状態 / 操作。
// ---------------------------------------------------------------------------
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    final TextStyle s = TofuTextStyles.captionBold.copyWith(
      color: TofuTokens.textTertiary,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space3,
      ),
      decoration: BoxDecoration(
        color: TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: 80, child: Text('整理券', style: s)),
          SizedBox(width: 88, child: Text('時刻', style: s)),
          Expanded(child: Text('商品', style: s)),
          SizedBox(width: 120, child: Text('金額', style: s, textAlign: TextAlign.right)),
          const SizedBox(width: TofuTokens.space5),
          SizedBox(width: 96, child: Text('状態', style: s)),
          const SizedBox(width: TofuTokens.space5),
          SizedBox(width: 80, child: Text('操作', style: s, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// landscape 行 (Figma 81:98): 横並びテーブル風。
// ---------------------------------------------------------------------------
class _HistoryRowWide extends StatelessWidget {
  const _HistoryRowWide({required this.order, required this.onCancel});
  final Order order;
  final Future<void> Function(Order) onCancel;

  @override
  Widget build(BuildContext context) {
    final bool cancelled = order.isCancelled;
    final TextStyle textStyle = TofuTextStyles.bodyMd.copyWith(
      decoration: cancelled ? TextDecoration.lineThrough : TextDecoration.none,
      color: cancelled ? TofuTokens.textTertiary : TofuTokens.textPrimary,
    );

    return Container(
      color: cancelled ? TofuTokens.bgSurface : TofuTokens.bgCanvas,
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space4,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              order.ticketNumber.toString(),
              style: TofuTextStyles.numberMd.copyWith(
                color: cancelled
                    ? TofuTokens.textTertiary
                    : TofuTokens.brandPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: Text(TofuFormat.hhmm(order.createdAt), style: textStyle),
          ),
          Expanded(
            child: Text(
              order.items
                  .map((it) => '${it.productName} × ${it.quantity}')
                  .join(' / '),
              style: textStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              TofuFormat.yen(order.finalPrice),
              style: TofuTextStyles.bodyMdBold.copyWith(
                decoration:
                    cancelled ? TextDecoration.lineThrough : TextDecoration.none,
                color: cancelled
                    ? TofuTokens.textTertiary
                    : TofuTokens.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: TofuTokens.space5),
          SizedBox(width: 96, child: _StatusChip(order: order)),
          const SizedBox(width: TofuTokens.space5),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: cancelled
                  ? Text(
                      '—',
                      style: TofuTextStyles.bodyMd.copyWith(
                        color: TofuTokens.textTertiary,
                      ),
                    )
                  : TofuButton(
                      label: '取消',
                      variant: TofuButtonVariant.secondary,
                      onPressed: () => onCancel(order),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// portrait 行: 縦積みコンパクト表示。
// ---------------------------------------------------------------------------
class _HistoryRowNarrow extends StatelessWidget {
  const _HistoryRowNarrow({required this.order, required this.onCancel});
  final Order order;
  final Future<void> Function(Order) onCancel;

  @override
  Widget build(BuildContext context) {
    final bool cancelled = order.isCancelled;
    return Container(
      color: cancelled ? TofuTokens.bgSurface : TofuTokens.bgCanvas,
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space4,
        vertical: TofuTokens.space4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: TofuTokens.space2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cancelled
                  ? TofuTokens.gray200
                  : TofuTokens.brandPrimarySubtle,
              borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
            ),
            child: Text(
              order.ticketNumber.toString(),
              style: TofuTextStyles.numberMd,
            ),
          ),
          const SizedBox(width: TofuTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  TofuFormat.mmddhhmm(order.createdAt),
                  style: TofuTextStyles.captionBold.copyWith(
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
                const SizedBox(height: TofuTokens.space2),
                _StatusChip(order: order),
              ],
            ),
          ),
          const SizedBox(width: TofuTokens.space4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                TofuFormat.yen(order.finalPrice),
                style: TofuTextStyles.bodyLgBold,
              ),
              if (!cancelled) ...<Widget>[
                const SizedBox(height: TofuTokens.space2),
                TofuButton(
                  label: '取消',
                  variant: TofuButtonVariant.secondary,
                  onPressed: () => onCancel(order),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[];
    chips.add(
      StatusIndicator.custom(
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
          OrderStatus.unsent => StatusIndicatorTone.warning,
          OrderStatus.sent => StatusIndicatorTone.info,
          OrderStatus.served => StatusIndicatorTone.success,
          OrderStatus.cancelled => StatusIndicatorTone.danger,
        },
        dense: true,
      ),
    );
    if (order.syncStatus == SyncStatus.notSynced) {
      chips.add(const SizedBox(width: TofuTokens.space2));
      chips.add(
        const StatusIndicator.custom(
          label: '未同期',
          icon: Icons.cloud_off,
          tone: StatusIndicatorTone.warning,
          dense: true,
        ),
      );
    }
    return Wrap(spacing: TofuTokens.space2, runSpacing: 2, children: chips);
  }
}
