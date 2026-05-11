import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/status_chip.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/calling_order.dart';
import '../../../../domain/enums/calling_status.dart';
import '../../../../providers/repository_providers.dart';
import '../notifiers/calling_providers.dart';

/// 呼び出し画面（仕様書 §6.3 / §9.5）。
///
/// - 「呼び出し前」「呼び出し済み」を 2 ペインで同時表示
/// - 呼び出し前カードをタップ → 整理券番号を大画面表示 → 閉じると済みへ
/// - 直前1件の Undo を SnackBar で提供
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
      body: SafeArea(
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
                final bool wide = constraints.maxWidth >= 768;
                return Column(
                  children: <Widget>[
                    const _Header(),
                    Expanded(
                      child: wide
                          ? Row(
                              children: <Widget>[
                                Expanded(
                                  child: _ColumnPane(
                                    title: '呼び出し前',
                                    accent: TofuTokens.brandPrimary,
                                    orders: pending,
                                    onTap: _showFullScreen,
                                    showCallButton: true,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  color: TofuTokens.borderSubtle,
                                ),
                                Expanded(
                                  child: _ColumnPane(
                                    title: '呼び出し済み',
                                    accent: TofuTokens.textTertiary,
                                    orders: called,
                                    onTap: null,
                                    showCallButton: false,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: <Widget>[
                                Expanded(
                                  child: _ColumnPane(
                                    title: '呼び出し前',
                                    accent: TofuTokens.brandPrimary,
                                    orders: pending,
                                    onTap: _showFullScreen,
                                    showCallButton: true,
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: _ColumnPane(
                                    title: '呼び出し済み',
                                    accent: TofuTokens.textTertiary,
                                    orders: called,
                                    onTap: null,
                                    showCallButton: false,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TofuTokens.bgCanvas,
        border: Border(bottom: BorderSide(color: TofuTokens.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space5,
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
            child: const Icon(Icons.campaign, color: TofuTokens.brandOnPrimary),
          ),
          const SizedBox(width: TofuTokens.space4),
          const Text('呼び出し', style: TofuTextStyles.h3),
        ],
      ),
    );
  }
}

class _ColumnPane extends StatelessWidget {
  const _ColumnPane({
    required this.title,
    required this.accent,
    required this.orders,
    required this.onTap,
    required this.showCallButton,
  });

  final String title;
  final Color accent;
  final List<CallingOrder> orders;
  final Future<void> Function(CallingOrder)? onTap;
  final bool showCallButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space4,
          ),
          color: TofuTokens.bgSurface,
          child: Row(
            children: <Widget>[
              Container(width: 4, height: 24, color: accent),
              const SizedBox(width: TofuTokens.space3),
              Text(title, style: TofuTextStyles.h4),
              const SizedBox(width: TofuTokens.space3),
              StatusChip(label: '${orders.length}件', dense: true),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? _EmptyState(label: '$title はありません')
              : LayoutBuilder(
                  builder: (c, constraints) {
                    final int cols = constraints.maxWidth >= 600 ? 2 : 1;
                    return GridView.builder(
                      padding: const EdgeInsets.all(TofuTokens.space5),
                      itemCount: orders.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: TofuTokens.space4,
                        crossAxisSpacing: TofuTokens.space4,
                        childAspectRatio: 1.6,
                      ),
                      itemBuilder: (c, i) => _CallingCard(
                        order: orders[i],
                        accent: accent,
                        onTap: onTap == null ? null : () => onTap!(orders[i]),
                        showCallButton: showCallButton,
                      ),
                    );
                  },
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

class _CallingCard extends StatelessWidget {
  const _CallingCard({
    required this.order,
    required this.accent,
    required this.onTap,
    required this.showCallButton,
  });

  final CallingOrder order;
  final Color accent;
  final VoidCallback? onTap;
  final bool showCallButton;

  @override
  Widget build(BuildContext context) {
    final bool isCancelled = order.status == CallingStatus.cancelled;
    return Material(
      color: isCancelled ? TofuTokens.dangerBg : TofuTokens.bgCanvas,
      borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        onTap: isCancelled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(TofuTokens.space5),
          decoration: BoxDecoration(
            border: Border.all(
              color: isCancelled ? TofuTokens.dangerBorder : accent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    if (isCancelled)
                      const StatusChip(
                        label: '取消',
                        icon: Icons.block,
                        tone: TofuStatusTone.danger,
                        dense: true,
                      ),
                    Text(
                      order.ticketNumber.toString(),
                      style: TofuTextStyles.numberLg.copyWith(
                        color: isCancelled ? TofuTokens.dangerText : accent,
                        fontSize: 56,
                      ),
                    ),
                    Text(
                      TofuFormat.relativeFromNow(order.receivedAt),
                      style: TofuTextStyles.captionBold.copyWith(
                        color: TofuTokens.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showCallButton)
                Icon(Icons.touch_app, size: 32, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

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
                size: TofuButtonSize.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
