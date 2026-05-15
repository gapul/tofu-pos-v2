import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/refresh_from_server.dart';
import '../../../../core/transport/transport.dart';
import '../../../../core/transport/transport_event.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/lordicon.dart';
import '../../../../core/ui/page_title.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/calling_order.dart';
import '../../../../domain/enums/calling_status.dart';
import '../../../../domain/value_objects/shop_id.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/usecase_providers.dart';
import '../notifiers/calling_providers.dart';

/// 呼び出し画面（仕様書 §6.3 / §9.5 / Figma `08-Caller-Home`）。
///
/// Figma レイアウト:
///   - landscape (id 436:506, 1024×768): 左ペイン「呼び出し前」(604w) +
///     右ペイン「呼び出し済」(420w, bgSurface tinted)。
///   - portrait  (id 436:507, 375×812):  Header + 縦リスト (呼び出し前 → 呼び出し済)。
///
/// 業務要件:
///   - `callingOrdersProvider` を購読し pending / called / cancelled を分離
///   - 呼び出し前カードをタップ → 整理券大画面表示 → 閉じると called へ遷移
///   - `callingOrderRepository.updateStatus` で状態更新（Undo SnackBar）
class CallingScreen extends ConsumerStatefulWidget {
  const CallingScreen({super.key});

  @override
  ConsumerState<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends ConsumerState<CallingScreen> {
  /// 既に自動全画面を出した orderId（同一注文の二重起動を防ぐ）。
  final Set<int> _autoOpened = <int>{};

  /// 現在 _FullScreenCallDialog が開いているか。
  bool _dialogOpen = false;

  /// 自動表示の待ち行列。ダイアログ閉じ後に先頭から順に開く。
  final List<CallingOrder> _autoQueue = <CallingOrder>[];

  Future<void> _markPickedUp(CallingOrder order) async {
    unawaited(HapticFeedback.lightImpact());
    await ref
        .read(callingOrderRepositoryProvider)
        .updateStatus(order.orderId, CallingStatus.pickedUp);
    // レジ端末で整理券プールを return できるよう OrderPickedUpEvent をブロードキャスト。
    try {
      final Transport transport =
          await ref.read(transportProvider.future);
      final ShopId? shopId =
          await ref.read(settingsRepositoryProvider).getShopId();
      if (shopId == null) return;
      await transport.send(
        OrderPickedUpEvent(
          shopId: shopId.value,
          eventId: const Uuid().v4(),
          occurredAt: DateTime.now(),
          orderId: order.orderId,
          ticketNumber: order.ticketNumber,
        ),
      );
    } catch (e, st) {
      AppLogger.w(
        'CallingScreen: broadcast order_picked_up failed',
        error: e,
        stackTrace: st,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('整理券 ${order.ticketNumber} を受取完了にしました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _markCalled(CallingOrder order) async {
    unawaited(HapticFeedback.mediumImpact());
    await ref
        .read(callingOrderRepositoryProvider)
        .updateStatus(order.orderId, CallingStatus.called);

    // サーバ側監査と他端末状態同期のため CallCompletedEvent を送信。
    // 失敗時は SnackBar で通知（fire-and-forget しない）。
    bool broadcastOk = true;
    try {
      await _broadcastCallCompleted(order);
    } catch (e) {
      broadcastOk = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('他端末への呼び出し通知に失敗: $e'),
            backgroundColor: TofuTokens.dangerBgStrong,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }
    if (broadcastOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('整理券 ${order.ticketNumber} を呼び出しました'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _broadcastCallCompleted(CallingOrder order) async {
    try {
      final Transport transport =
          await ref.read(transportProvider.future);
      final ShopId? shopId =
          await ref.read(settingsRepositoryProvider).getShopId();
      if (shopId == null) return;
      await transport.send(
        CallCompletedEvent(
          shopId: shopId.value,
          eventId: const Uuid().v4(),
          occurredAt: DateTime.now(),
          orderId: order.orderId,
          ticketNumber: order.ticketNumber,
        ),
      );
    } catch (e, st) {
      AppLogger.w(
        'CallingScreen: broadcast call_completed failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _showFullScreen(CallingOrder order) async {
    if (_dialogOpen) {
      // 既にダイアログが開いている場合は待ち行列に積む。
      if (!_autoQueue.any((o) => o.orderId == order.orderId)) {
        _autoQueue.add(order);
      }
      return;
    }
    _dialogOpen = true;
    _autoOpened.add(order.orderId);
    final bool? markCalled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => _FullScreenCallDialog(order: order),
    );
    _dialogOpen = false;
    if (markCalled ?? false) {
      await _markCalled(order);
    }
    // 待ち行列に積まれた次の注文を順に表示。
    if (!mounted) return;
    if (_autoQueue.isNotEmpty) {
      final CallingOrder next = _autoQueue.removeAt(0);
      // この frame では別の listen からも再帰する可能性があるので microtask に投げる。
      unawaited(Future<void>.microtask(() {
        if (mounted) _showFullScreen(next);
      }));
    }
  }

  /// pending リストの変化を見て、新規 pending を自動全画面表示する。
  void _handleOrdersChange(
    List<CallingOrder>? previous,
    List<CallingOrder> next,
  ) {
    final List<CallingOrder> pending = next
        .where((o) => o.status == CallingStatus.pending)
        .toList();
    // 起動時の初期 pending も含めて、未表示のものを順に開く。
    for (final CallingOrder o in pending) {
      if (_autoOpened.contains(o.orderId)) continue;
      // 表示済みでないものを発見した場合: ダイアログを開く（あるいは queue へ）。
      unawaited(_showFullScreen(o));
    }
    // pending から消えた orderId は _autoOpened から落として、
    // 同じ番号が再度 pending に戻った（取消し→復帰）ときに再度開けるようにする。
    final Set<int> stillPending = pending.map((o) => o.orderId).toSet();
    _autoOpened.removeWhere(
      (id) =>
          !stillPending.contains(id) &&
          !_autoQueue.any((o) => o.orderId == id) &&
          !_dialogOpen,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 新規 pending が現れた瞬間に _FullScreenCallDialog を自動表示する。
    // 二重表示防止 / 待ち行列 / 取消し→復帰の再表示は _handleOrdersChange 側で管理。
    ref.listen<AsyncValue<List<CallingOrder>>>(callingOrdersProvider, (prev, next) {
      final List<CallingOrder>? prevList = prev?.value;
      final List<CallingOrder>? nextList = next.value;
      if (nextList == null) return;
      _handleOrdersChange(prevList, nextList);
    });

    final AsyncValue<List<CallingOrder>> orders = ref.watch(
      callingOrdersProvider,
    );

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppHeader(
        title: '呼び出し',
        // /regi/calling から push されたときだけ戻るボタンを出す。
        // 呼び出し役の役割ホームとして開いているときは戻り先がないので非表示。
        // go_router 不在の widget test でも安全に動くよう Navigator.canPop で判定。
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : Navigator.pop(context),
                tooltip: '戻る',
              )
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: '設定',
            icon: const Lordicon(
              name: 'settings',
              fallbackIcon: Icons.settings,
              semanticLabel: '設定',
            ),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const PageTitle(
              title: '呼び出し',
              leading: Lordicon(
                name: 'bell',
                fallbackIcon: Icons.notifications_active,
                size: 28,
                semanticLabel: '呼び出し',
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await RefreshFromServer.calling(ref);
                  ref.invalidate(callingOrdersProvider);
                },
                child: orders.when(
          data: (all) {
            final List<CallingOrder> pending = all
                .where((o) => o.status == CallingStatus.pending)
                .toList();
            final List<CallingOrder> called = all
                .where(
                  (o) =>
                      o.status == CallingStatus.called ||
                      o.status == CallingStatus.cancelled,
                )
                .toList();
            return LayoutBuilder(
              builder: (c, constraints) {
                final bool wide = constraints.maxWidth >= 720;
                if (wide) {
                  // Figma landscape (436:506): 横 2 ペイン構成。
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        flex: 604,
                        child: _PendingPane(
                          orders: pending,
                          onTap: _showFullScreen,
                        ),
                      ),
                      Expanded(
                        flex: 420,
                        child: _CalledPane(
                          orders: called,
                          onTap: _markPickedUp,
                        ),
                      ),
                    ],
                  );
                }
                // Figma portrait (436:507): 縦 2 セクション。
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: _PendingPane(
                        orders: pending,
                        onTap: _showFullScreen,
                      ),
                    ),
                    Expanded(
                      child: _CalledPane(
                        orders: called,
                        onTap: _markPickedUp,
                      ),
                    ),
                  ],
                );
              },
            );
          },
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
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 呼び出し前ペイン (Figma 76:86): bgCanvas + 大型 160×160 カード横並び
// ---------------------------------------------------------------------------
class _PendingPane extends StatelessWidget {
  const _PendingPane({required this.orders, required this.onTap});

  final List<CallingOrder> orders;
  final Future<void> Function(CallingOrder) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TofuTokens.bgCanvas,
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space7,
        vertical: TofuTokens.space7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PaneTitle(
            title: '呼び出し前',
            count: orders.length,
            accent: TofuTokens.brandPrimary,
          ),
          const SizedBox(height: TofuTokens.space5),
          Expanded(
            child: orders.isEmpty
                ? const _EmptyState(label: '呼び出し前の注文はありません')
                : GridView.builder(
                    // Figma: 160×160 が 3 つ横並び。
                    padding: EdgeInsets.zero,
                    itemCount: orders.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: TofuTokens.space5,
                      crossAxisSpacing: TofuTokens.space5,
                    ),
                    itemBuilder: (c, i) => _LargeTicketCard(
                      key: ValueKey<String>(
                        'large-ticket-${orders[i].orderId}',
                      ),
                      order: orders[i],
                      onTap: () => onTap(orders[i]),
                    ).animate().fadeIn(
                      duration: TofuTokens.motionShort,
                    ).slideY(
                      begin: 0.08,
                      end: 0,
                      duration: TofuTokens.motionMedium,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 呼び出し済ペイン (Figma 76:100): bgSurface + コンパクト 110×110 カード
// ---------------------------------------------------------------------------
class _CalledPane extends StatelessWidget {
  const _CalledPane({required this.orders, required this.onTap});
  final List<CallingOrder> orders;
  final Future<void> Function(CallingOrder) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TofuTokens.bgSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space7,
        vertical: TofuTokens.space7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PaneTitle(
            title: '呼び出し済',
            count: orders.length,
            accent: TofuTokens.textTertiary,
          ),
          const SizedBox(height: TofuTokens.space5),
          Expanded(
            child: orders.isEmpty
                ? const _EmptyState(label: '呼び出し済はありません')
                : GridView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: orders.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 140,
                      mainAxisSpacing: TofuTokens.space4,
                      crossAxisSpacing: TofuTokens.space4,
                    ),
                    itemBuilder: (c, i) => _SmallTicketCard(
                      key: ValueKey<String>(
                        'small-ticket-${orders[i].orderId}',
                      ),
                      order: orders[i],
                      onTap: orders[i].status == CallingStatus.called
                          ? () => onTap(orders[i])
                          : null,
                    ).animate().fadeIn(
                      duration: TofuTokens.motionShort,
                    ).slideX(
                      begin: 0.06,
                      end: 0,
                      duration: TofuTokens.motionMedium,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaneTitle extends StatelessWidget {
  const _PaneTitle({
    required this.title,
    required this.accent,
    required this.count,
  });
  final String title;
  final Color accent;
  final int count;

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
        Text(
          '$count件',
          style: TofuTextStyles.bodySmBold.copyWith(
            color: TofuTokens.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TofuTextStyles.bodyLg.copyWith(color: TofuTokens.textTertiary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 大型整理券カード (Figma 76:91, 160×160): 呼び出し前。タップで全画面表示。
// ---------------------------------------------------------------------------
class _LargeTicketCard extends StatelessWidget {
  const _LargeTicketCard({
    required this.order,
    required this.onTap,
    super.key,
  });
  final CallingOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isCancelled = order.status == CallingStatus.cancelled;
    // Figma 76:91 — 角丸は tl/tr=xl(16), bl/br=2xl(24) の非対称
    const BorderRadius cardRadius = BorderRadius.only(
      topLeft: Radius.circular(TofuTokens.radiusXl),
      topRight: Radius.circular(TofuTokens.radiusXl),
      bottomLeft: Radius.circular(TofuTokens.radius2xl),
      bottomRight: Radius.circular(TofuTokens.radius2xl),
    );
    return Material(
      color: isCancelled ? TofuTokens.dangerBg : TofuTokens.brandPrimarySubtle,
      borderRadius: cardRadius,
      child: InkWell(
        borderRadius: cardRadius,
        onTap: isCancelled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space8,
            vertical: TofuTokens.space7,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isCancelled
                  ? TofuTokens.dangerBorder
                  : TofuTokens.brandPrimary,
              width: TofuTokens.strokeThick,
            ),
            borderRadius: cardRadius,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              Expanded(
                child: Center(
                  child: FittedBox(
                    child: Text(
                      order.ticketNumber.toString(),
                      style: const TextStyle(
                        fontFamily: TofuTokens.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 72,
                        height: 80 / 72,
                        letterSpacing: -1.44,
                      ).copyWith(
                        color: isCancelled
                            ? TofuTokens.dangerText
                            : TofuTokens.brandPrimary,
                      ),
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

// ---------------------------------------------------------------------------
// 小型整理券カード (Figma 76:105, 110×110): 呼び出し済。
// ---------------------------------------------------------------------------
class _SmallTicketCard extends StatelessWidget {
  const _SmallTicketCard({required this.order, this.onTap, super.key});
  final CallingOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isCancelled = order.status == CallingStatus.cancelled;
    // Figma 76:105 — bgMuted / radiusLg / 48px textTertiary
    final BorderRadius radius =
        BorderRadius.circular(TofuTokens.radiusLg);
    return Material(
      color: isCancelled ? TofuTokens.dangerBg : TofuTokens.bgMuted,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space7,
        vertical: TofuTokens.space6,
      ),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: isCancelled
              ? TofuTokens.dangerBorder
              : TofuTokens.borderSubtle,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Center(
              child: FittedBox(
                child: Text(
                  order.ticketNumber.toString(),
                  style: TofuTextStyles.displayS.copyWith(
                    color: isCancelled
                        ? TofuTokens.dangerText
                        : TofuTokens.textTertiary,
                    height: 56 / 48,
                  ),
                ),
              ),
            ),
          ),
          if (isCancelled)
            Text(
              '取消',
              style: TofuTextStyles.captionBold.copyWith(
                color: TofuTokens.dangerText,
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 全画面呼び出しダイアログ: 整理券番号を顧客向けに巨大表示。
// 上部寄せ。**自動 close は廃止**: 右下「呼び出し済み」ボタンを押した場合のみ
// markCalled する (pop(true))。barrierDismissible で閉じた場合は markCalled
// しない (pop(false))。
// ---------------------------------------------------------------------------
class _FullScreenCallDialog extends StatefulWidget {
  const _FullScreenCallDialog({required this.order});
  final CallingOrder order;

  @override
  State<_FullScreenCallDialog> createState() => _FullScreenCallDialogState();
}

class _FullScreenCallDialogState extends State<_FullScreenCallDialog> {
  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      // ハードウェアバック等で閉じた場合は markCalled しない。
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Dialog.fullscreen(
      backgroundColor: TofuTokens.brandPrimary,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            // 上部寄せレイアウト
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TofuTokens.space7,
                TofuTokens.space11,
                TofuTokens.space7,
                TofuTokens.space7,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'お呼び出し',
                    style: TofuTextStyles.h2.copyWith(
                      color: TofuTokens.brandOnPrimary,
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space5),
                  Text(
                    '整理券',
                    style: TofuTextStyles.h3.copyWith(
                      color: TofuTokens.brandOnPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space4),
                  // 整理券番号: 画面いっぱいの大型表示
                  Text(
                    widget.order.ticketNumber.toString(),
                    style: const TextStyle(
                      fontFamily: TofuTokens.fontFamily,
                      fontSize: 320,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: TofuTokens.brandOnPrimary,
                      letterSpacing: -8,
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space5),
                  Text(
                    'お受け取りください',
                    style: TofuTextStyles.h3.copyWith(
                      color: TofuTokens.brandOnPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // 「呼び出し済み」ボタン: 押下時のみ markCalled する。
            Positioned(
              right: TofuTokens.space7,
              bottom: TofuTokens.space7,
              child: TofuButton(
                label: '呼び出し済み',
                icon: Icons.check_circle,
                variant: TofuButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
            // 単に閉じるだけのサブボタン（誤操作のリカバリ用）。
            Positioned(
              left: TofuTokens.space7,
              bottom: TofuTokens.space7,
              child: TofuButton(
                label: '閉じる',
                icon: Icons.close,
                variant: TofuButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
