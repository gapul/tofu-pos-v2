import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/lordicon.dart';
import '../../../../core/ui/page_title.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/calling_order.dart';
import '../../../../domain/enums/calling_status.dart';
import '../../../../providers/repository_providers.dart';
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
  Future<void> _markCalled(CallingOrder order) async {
    unawaited(HapticFeedback.mediumImpact());
    await ref
        .read(callingOrderRepositoryProvider)
        .updateStatus(order.orderId, CallingStatus.called);

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('整理券 ${order.ticketNumber} を呼び出し済みにしました'),
        action: SnackBarAction(
          label: '取り消し',
          onPressed: () async {
            await ref
                .read(callingOrderRepositoryProvider)
                .updateStatus(order.orderId, CallingStatus.pending);
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _showFullScreen(CallingOrder order) async {
    final bool? markCalled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => _FullScreenCallDialog(order: order),
    );
    if (markCalled ?? false) {
      await _markCalled(order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CallingOrder>> orders = ref.watch(
      callingOrdersProvider,
    );

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: const AppHeader(title: '呼び出し'),
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
                        child: _CalledPane(orders: called),
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
                    Expanded(child: _CalledPane(orders: called)),
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
  const _CalledPane({required this.orders});
  final List<CallingOrder> orders;

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
  const _SmallTicketCard({required this.order, super.key});
  final CallingOrder order;

  @override
  Widget build(BuildContext context) {
    final bool isCancelled = order.status == CallingStatus.cancelled;
    // Figma 76:105 — bgMuted / radiusLg / 48px textTertiary
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space7,
        vertical: TofuTokens.space6,
      ),
      decoration: BoxDecoration(
        color: isCancelled ? TofuTokens.dangerBg : TofuTokens.bgMuted,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
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
    );
  }
}

// ---------------------------------------------------------------------------
// 全画面呼び出しダイアログ: 整理券番号を顧客向けに巨大表示。
// ---------------------------------------------------------------------------
class _FullScreenCallDialog extends StatelessWidget {
  const _FullScreenCallDialog({required this.order});
  final CallingOrder order;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: TofuTokens.brandPrimary,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'お呼び出し',
                    style: TofuTextStyles.h2.copyWith(
                      color: TofuTokens.brandOnPrimary,
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space7),
                  Text(
                    '整理券',
                    style: TofuTextStyles.h3.copyWith(
                      color: TofuTokens.brandOnPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space5),
                  // 整理券番号: 画面いっぱいの大型表示
                  Text(
                    order.ticketNumber.toString(),
                    style: const TextStyle(
                      fontFamily: TofuTokens.fontFamily,
                      fontSize: 320,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: TofuTokens.brandOnPrimary,
                      letterSpacing: -8,
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space7),
                  Text(
                    'お受け取りください',
                    style: TofuTextStyles.h3.copyWith(
                      color: TofuTokens.brandOnPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: TofuTokens.space7,
              bottom: TofuTokens.space7,
              child: TofuButton(
                label: '閉じる（呼び出し済みへ）',
                icon: Icons.close,
                size: TofuButtonSize.lg,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
