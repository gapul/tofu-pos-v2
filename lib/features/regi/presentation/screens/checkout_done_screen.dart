import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/ticket_number.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/enums/order_status.dart';

/// 会計完了画面（Figma `06-Register-Complete` / 仕様書 §6.1）。
///
/// レイアウト (Figma 1024×768, 中央寄せ):
/// - TicketNumber (display)
/// - H2「会計を承りました」
/// - サブ「整理券は番号順にお呼びします。番号札をお渡しください。」
/// - 注文サマリーカード (bgSurface, radius=lg, padding=20):
///   - 行 1: 「点数」 + 内訳「商品名×N / ...」
///   - 行 2: 「合計」 + 金額 (H3)
///   - 行 3: 「預り」 + 金額
///   - 行 4: 「お釣り」 + 金額
/// - 主要ボタン「次のお客様 →」(fullWidth, primary lg)
///
/// 確定後の軽いバウンスは TicketNumber を Tween で表現 (仕様書 §12.1)。
class CheckoutDoneScreen extends ConsumerStatefulWidget {
  const CheckoutDoneScreen({required this.order, super.key});
  final Order order;

  @override
  ConsumerState<CheckoutDoneScreen> createState() => _CheckoutDoneScreenState();
}

class _CheckoutDoneScreenState extends ConsumerState<CheckoutDoneScreen> {
  static const Duration _autoAdvance = Duration(milliseconds: 2500);
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer(_autoAdvance, () {
      if (!mounted) return;
      context.go('/regi/products');
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool unsent = widget.order.orderStatus == OrderStatus.unsent;
    final int itemCount = widget.order.items.length;
    final String itemSummary = widget.order.items
        .map((it) => '${it.productName} × ${it.quantity}')
        .join(' / ');

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TofuTokens.space8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 1. TicketNumber (display)
                  Center(
                    child: TweenAnimationBuilder<double>(
                      duration: TofuTokens.motionMedium,
                      tween: Tween<double>(begin: 0.85, end: 1),
                      curve: Curves.easeOutBack,
                      builder: (c, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: TicketNumber(
                        number: widget.order.ticketNumber.toString(),
                        label: '整理券',
                        size: TicketNumberSize.display,
                      ),
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space7), // 24
                  // 2. タイトル
                  const Text(
                    '会計を承りました',
                    style: TofuTextStyles.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: TofuTokens.space4), // 12
                  // 3. サブテキスト
                  Text(
                    '整理券は番号順にお呼びします。番号札をお渡しください。',
                    style: TofuTextStyles.bodySm.copyWith(
                      color: TofuTokens.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: TofuTokens.space7),
                  // 4. 注文サマリーカード
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TofuTokens.space6, // 20
                      vertical: TofuTokens.space5, // 16
                    ),
                    decoration: BoxDecoration(
                      color: TofuTokens.bgSurface,
                      borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
                      border: Border.all(color: TofuTokens.borderSubtle),
                    ),
                    child: Column(
                      children: <Widget>[
                        _SummaryRow(
                          label: '$itemCount点',
                          value: itemSummary,
                          valueStyle: TofuTextStyles.bodyMd.copyWith(
                            color: TofuTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: TofuTokens.space4),
                        _SummaryRow(
                          label: '合計',
                          value: TofuFormat.yen(widget.order.finalPrice),
                          valueStyle: TofuTextStyles.h3,
                        ),
                        const SizedBox(height: TofuTokens.space4),
                        _SummaryRow(
                          label: '預り',
                          value: TofuFormat.yen(widget.order.receivedCash),
                          valueStyle: TofuTextStyles.bodyMdBold,
                        ),
                        const SizedBox(height: TofuTokens.space4),
                        _SummaryRow(
                          label: 'お釣り',
                          value: TofuFormat.yen(widget.order.changeCash),
                          valueStyle: TofuTextStyles.bodyMdBold,
                        ),
                      ],
                    ),
                  ),
                  if (unsent) ...<Widget>[
                    const SizedBox(height: TofuTokens.space4),
                    Container(
                      padding: const EdgeInsets.all(TofuTokens.space4),
                      decoration: BoxDecoration(
                        color: TofuTokens.warningBg,
                        border: Border.all(color: TofuTokens.warningBorder),
                        borderRadius: BorderRadius.circular(
                          TofuTokens.radiusMd,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.warning_amber,
                            color: TofuTokens.warningIcon,
                          ),
                          const SizedBox(width: TofuTokens.space3),
                          Expanded(
                            child: Text(
                              'キッチンへの送信ができていません。会計データはローカルに保存済みです。',
                              style: TofuTextStyles.bodySm.copyWith(
                                color: TofuTokens.warningText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: TofuTokens.space8), // 32
                  // 自動遷移インジケーター（操作不要）
                  Center(
                    child: Text(
                      '間もなく次のお客様の画面に切り替わります…',
                      style: TofuTextStyles.bodySm.copyWith(
                        color: TofuTokens.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space3),
                  TweenAnimationBuilder<double>(
                    duration: _autoAdvance,
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (c, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 3,
                      backgroundColor: TofuTokens.borderSubtle,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        TofuTokens.brandPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TofuTextStyles.bodySm.copyWith(
              color: TofuTokens.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: TofuTokens.space5),
        Expanded(
          child: Text(
            value,
            style: valueStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
