import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/ticket_badge.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/enums/order_status.dart';

/// 会計完了画面（仕様書 §6.1）。
///
/// 整理券番号を大画面表示。確定操作の成功時の軽いバウンスは Hero ではなく
/// TweenAnimationBuilder で表現する（仕様書 §12.1）。
class CheckoutDoneScreen extends ConsumerStatefulWidget {
  const CheckoutDoneScreen({required this.order, super.key});
  final Order order;

  @override
  ConsumerState<CheckoutDoneScreen> createState() => _CheckoutDoneScreenState();
}

class _CheckoutDoneScreenState extends ConsumerState<CheckoutDoneScreen> {
  @override
  Widget build(BuildContext context) {
    final bool sent = widget.order.orderStatus == OrderStatus.sent;
    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(TofuTokens.space8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TweenAnimationBuilder<double>(
                    duration: TofuTokens.motionMedium,
                    tween: Tween<double>(begin: 0.85, end: 1.05),
                    curve: Curves.easeOutBack,
                    builder: (c, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      decoration: BoxDecoration(
                        color: TofuTokens.successBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: TofuTokens.successBorder,
                          width: 3,
                        ),
                      ),
                      padding: const EdgeInsets.all(TofuTokens.space5),
                      child: const Icon(
                        Icons.check,
                        size: 56,
                        color: TofuTokens.successIcon,
                      ),
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space7),
                  const Text('会計が完了しました', style: TofuTextStyles.h2),
                  const SizedBox(height: TofuTokens.space7),
                  TicketBadge(
                    ticket: widget.order.ticketNumber,
                    size: TicketBadgeSize.display,
                  ),
                  const SizedBox(height: TofuTokens.space7),
                  Text(
                    '請求金額  ${TofuFormat.yen(widget.order.finalPrice)}',
                    style: TofuTextStyles.h3,
                  ),
                  if (widget.order.changeCash.isPositive) ...<Widget>[
                    const SizedBox(height: TofuTokens.space2),
                    Text(
                      'お釣り  ${TofuFormat.yen(widget.order.changeCash)}',
                      style: TofuTextStyles.bodyLg.copyWith(
                        color: TofuTokens.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: TofuTokens.space5),
                  if (!sent && widget.order.orderStatus == OrderStatus.unsent)
                    Padding(
                      padding: const EdgeInsets.only(top: TofuTokens.space3),
                      child: Container(
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
                    ),
                  const SizedBox(height: TofuTokens.space11),
                  TofuButton(
                    label: '次のお客様へ',
                    icon: Icons.arrow_forward,
                    size: TofuButtonSize.primary,
                    fullWidth: true,
                    onPressed: () => context.go('/'),
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
