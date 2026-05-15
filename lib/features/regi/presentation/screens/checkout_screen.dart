import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exceptions.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/num_stepper.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/value_objects/denomination.dart';
import '../../../../domain/value_objects/discount.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../providers/settings_providers.dart';
import '../notifiers/checkout_session.dart';
import '../notifiers/regi_providers.dart';

/// 会計画面（仕様書 §6.1.3 / §9.3）。
///
/// M3 リファクタ: 会計確定の業務ロジックは
/// `CheckoutConfirmController` (AsyncNotifier) に抽出済み。
/// 本画面は `listen` で AsyncValue を購読し、SnackBar/遷移のみ扱う。
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  void _showSnack(BuildContext context, String message, {Color? bg}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: bg));
  }

  void _handleConfirmResult(
    BuildContext context,
    AsyncValue<Order?>? previous,
    AsyncValue<Order?> next,
  ) {
    // data(non-null) は確定成功 → 完了画面へ。
    next.whenOrNull(
      data: (order) {
        if (order != null && previous?.value != order) {
          unawaited(HapticFeedback.heavyImpact());
          context.go('/regi/done', extra: order);
        }
      },
      error: (error, _) {
        if (previous?.error == error) {
          return;
        }
        if (isCheckoutValidationError(error)) {
          _showSnack(context, checkoutValidationMessage(error));
          return;
        }
        if (isTransportDeliveryError(error)) {
          final TransportDeliveryException e =
              error as TransportDeliveryException;
          _showSnack(
            context,
            e.message,
            bg: TofuTokens.dangerBgStrong,
          );
          // ローカル保存は完了済 → ホームへ戻す（Controller 側で reset 済）。
          context.go('/');
          return;
        }
        if (error is TicketPoolExhaustedException) {
          _showSnack(context, error.message);
          return;
        }
        // InsufficientStockException その他
        _showSnack(context, '$error');
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CheckoutSession session = ref.watch(checkoutSessionProvider);
    final CheckoutSessionNotifier notifier = ref.read(
      checkoutSessionProvider.notifier,
    );
    final FeatureFlags flags =
        ref.watch(featureFlagsProvider).value ?? FeatureFlags.allOff;
    final AsyncValue<Order?> confirmState = ref.watch(
      checkoutConfirmControllerProvider,
    );
    final bool confirming = confirmState.isLoading;

    ref.listen<AsyncValue<Order?>>(
      checkoutConfirmControllerProvider,
      (prev, next) => _handleConfirmResult(context, prev, next),
    );

    Future<void> onConfirm() async {
      // 軽量ガード: 業務例外は Controller 側で AsyncValue.error にする。
      try {
        await ref
            .read(checkoutConfirmControllerProvider.notifier)
            .confirm();
      } catch (_) {
        // listen() 側で SnackBar 表示。ここでは握り潰し OK。
      }
    }

    return LayoutBuilder(
      builder: (c, constraints) {
        final bool wide = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: TofuTokens.bgCanvas,
          appBar: AppHeader(
            title: '会計',
            upcomingTicket: ref.watch(upcomingTicketProvider).value,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
              tooltip: '戻る',
            ),
          ),
          body: SafeArea(
            child: wide
                ? _LandscapeLayout(
                    session: session,
                    notifier: notifier,
                    flags: flags,
                    confirming: confirming,
                    onConfirm: onConfirm,
                  )
                : _PortraitLayout(
                    session: session,
                    notifier: notifier,
                    flags: flags,
                    confirming: confirming,
                    onConfirm: onConfirm,
                  ),
          ),
        );
      },
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({
    required this.session,
    required this.notifier,
    required this.flags,
    required this.confirming,
    required this.onConfirm,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final FeatureFlags flags;
  final bool confirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: _LeftSide(session: session, notifier: notifier, flags: flags),
        ),
        SizedBox(
          width: 380,
          child: _RightActions(
            session: session,
            notifier: notifier,
            flags: flags,
            confirming: confirming,
            onConfirm: onConfirm,
          ),
        ),
      ],
    );
  }
}

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({
    required this.session,
    required this.notifier,
    required this.flags,
    required this.confirming,
    required this.onConfirm,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final FeatureFlags flags;
  final bool confirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _LeftSide(session: session, notifier: notifier, flags: flags),
        ),
        Container(
          decoration: const BoxDecoration(
            color: TofuTokens.bgCanvas,
            border: Border(top: BorderSide(color: TofuTokens.borderSubtle)),
          ),
          child: _RightActions(
            session: session,
            notifier: notifier,
            flags: flags,
            confirming: confirming,
            onConfirm: onConfirm,
          ),
        ),
      ],
    );
  }
}

class _LeftSide extends StatelessWidget {
  const _LeftSide({
    required this.session,
    required this.notifier,
    required this.flags,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final FeatureFlags flags;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TofuTokens.space5),
      children: <Widget>[
        _ItemsSummary(session: session),
        const SizedBox(height: TofuTokens.space5),
        _DiscountSection(session: session, notifier: notifier),
        const SizedBox(height: TofuTokens.space5),
        if (flags.cashManagement)
          _CashManagementSection(session: session, notifier: notifier)
        else
          _SimpleCashInput(session: session, notifier: notifier),
        const SizedBox(height: TofuTokens.space11),
      ],
    );
  }
}

class _ItemsSummary extends StatelessWidget {
  const _ItemsSummary({required this.session});
  final CheckoutSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        color: TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('注文内容', style: TofuTextStyles.h4),
          const SizedBox(height: TofuTokens.space3),
          for (final OrderItem it in session.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TofuTokens.space2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(it.productName, style: TofuTextStyles.bodyMd),
                  ),
                  Text('×${it.quantity}', style: TofuTextStyles.bodyMdBold),
                  const SizedBox(width: TofuTokens.space5),
                  SizedBox(
                    width: 90,
                    child: Text(
                      TofuFormat.yen(it.subtotal),
                      textAlign: TextAlign.right,
                      style: TofuTextStyles.bodyMdBold,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Row(
            children: <Widget>[
              const Text('合計', style: TofuTextStyles.bodyLgBold),
              const Spacer(),
              Text(
                TofuFormat.yen(session.totalPrice),
                style: TofuTextStyles.h3,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscountSection extends StatefulWidget {
  const _DiscountSection({required this.session, required this.notifier});
  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;

  @override
  State<_DiscountSection> createState() => _DiscountSectionState();
}

class _DiscountSectionState extends State<_DiscountSection> {
  late TextEditingController _controller;
  bool _isPercent = false;
  late int _signValue;

  @override
  void initState() {
    super.initState();
    final Discount d = widget.session.discount;
    if (d is AmountDiscount) {
      _isPercent = false;
      _signValue = d.amount.yen;
    } else if (d is PercentDiscount) {
      _isPercent = true;
      _signValue = d.percent;
    } else {
      _signValue = 0;
    }
    _controller = TextEditingController(
      text: _signValue == 0 ? '' : _signValue.abs().toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit() {
    final int abs = int.tryParse(_controller.text) ?? 0;
    final int signed = _signValue >= 0 ? abs : -abs;
    if (_isPercent) {
      widget.notifier.setDiscount(PercentDiscount(signed));
    } else {
      widget.notifier.setDiscount(AmountDiscount(Money(signed)));
    }
  }

  void _toggleSign(bool isDiscount) {
    final int abs = int.tryParse(_controller.text) ?? 0;
    setState(() => _signValue = isDiscount ? -abs : abs);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final Money preview = widget.session.discount.applyTo(
      widget.session.totalPrice,
    );
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        border: Border.all(color: TofuTokens.borderSubtle),
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('割引・割増（任意）', style: TofuTextStyles.h4),
          const SizedBox(height: TofuTokens.space3),
          Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('割引'),
                selected: _signValue <= 0,
                onSelected: (_) => _toggleSign(true),
              ),
              const SizedBox(width: TofuTokens.space3),
              ChoiceChip(
                label: const Text('割増'),
                selected: _signValue > 0,
                onSelected: (_) => _toggleSign(false),
              ),
              const SizedBox(width: TofuTokens.space5),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textAlign: TextAlign.right,
                  style: TofuTextStyles.h3,
                  onChanged: (_) => _emit(),
                  decoration: const InputDecoration(hintText: '0'),
                ),
              ),
              const SizedBox(width: TofuTokens.space3),
              ToggleButtons(
                isSelected: <bool>[!_isPercent, _isPercent],
                onPressed: (i) {
                  setState(() => _isPercent = i == 1);
                  _emit();
                },
                borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                children: const <Widget>[Text('円'), Text('％')],
              ),
            ],
          ),
          const SizedBox(height: TofuTokens.space3),
          Row(
            children: <Widget>[
              Text(
                '適用後',
                style: TofuTextStyles.bodySm.copyWith(
                  color: TofuTokens.textTertiary,
                ),
              ),
              const Spacer(),
              Text(TofuFormat.yen(preview), style: TofuTextStyles.h3),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleCashInput extends StatelessWidget {
  const _SimpleCashInput({required this.session, required this.notifier});
  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        border: Border.all(color: TofuTokens.borderSubtle),
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('預り金', style: TofuTextStyles.h4),
          const SizedBox(height: TofuTokens.space4),
          TofuNumStepper(
            value: session.receivedCash.yen,
            onChanged: (v) => notifier.setReceivedCash(Money(v)),
            max: 1000000,
            step: 100,
            suffix: '円',
            formatter: (v) => TofuFormat.yenInt(v).replaceAll('¥', ''),
          ),
        ],
      ),
    );
  }
}

class _CashManagementSection extends StatelessWidget {
  const _CashManagementSection({required this.session, required this.notifier});
  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;

  void _bumpDenomination(Denomination d, int delta) {
    final Map<int, int> next = Map<int, int>.from(session.cashDelta);
    next[d.yen] = (next[d.yen] ?? 0) + delta;
    notifier.setCashDelta(next);
    int sum = 0;
    next.forEach((yen, count) => sum += yen * count);
    if (sum < 0) {
      sum = 0;
    }
    notifier.setReceivedCash(Money(sum));
  }

  @override
  Widget build(BuildContext context) {
    final List<Denomination> denoms = Denomination.all.reversed.toList();
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        border: Border.all(color: TofuTokens.borderSubtle),
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('預り金（金種別）', style: TofuTextStyles.h4),
          const SizedBox(height: TofuTokens.space2),
          Text(
            '+ で受領、− でお釣りとして返金',
            style: TofuTextStyles.bodySm.copyWith(
              color: TofuTokens.textTertiary,
            ),
          ),
          const SizedBox(height: TofuTokens.space5),
          for (final Denomination d in denoms) ...<Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 90,
                  child: Text('¥${d.yen}', style: TofuTextStyles.bodyLgBold),
                ),
                Expanded(
                  child: TofuNumStepper(
                    value: session.cashDelta[d.yen] ?? 0,
                    onChanged: (v) {
                      final int diff = v - (session.cashDelta[d.yen] ?? 0);
                      _bumpDenomination(d, diff);
                    },
                    min: -999,
                    max: 999,
                    suffix: '枚',
                  ),
                ),
              ],
            ),
            const SizedBox(height: TofuTokens.space3),
          ],
        ],
      ),
    );
  }
}

class _RightActions extends StatelessWidget {
  const _RightActions({
    required this.session,
    required this.notifier,
    required this.flags,
    required this.confirming,
    required this.onConfirm,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final FeatureFlags flags;
  final bool confirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final Money finalPrice = session.finalPrice;
    final Money change = session.changeCash;
    final bool insufficient = change.isNegative;

    return Padding(
      padding: const EdgeInsets.all(TofuTokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SummaryCard(
            label: '請求金額',
            value: TofuFormat.yen(finalPrice),
            highlight: true,
          ),
          const SizedBox(height: TofuTokens.space4),
          _SummaryCard(
            label: '預り金',
            value: TofuFormat.yen(session.receivedCash),
          ),
          const SizedBox(height: TofuTokens.space4),
          _SummaryCard(
            label: insufficient ? '不足' : 'お釣り',
            value: TofuFormat.yen(change.abs()),
            tone: insufficient
                ? StatusIndicatorTone.danger
                : (change.isZero
                      ? StatusIndicatorTone.neutral
                      : StatusIndicatorTone.success),
          ),
          const SizedBox(height: TofuTokens.space5),
          if (!flags.cashManagement) ...<Widget>[
            const Text('クイック金額', style: TofuTextStyles.bodySmBold),
            const SizedBox(height: TofuTokens.space3),
            Wrap(
              spacing: TofuTokens.space3,
              runSpacing: TofuTokens.space3,
              children: <Widget>[
                for (final int v in <int>[100, 500, 1000, 5000, 10000])
                  _QuickButton(
                    label: '+${TofuFormat.yenInt(v).replaceAll('¥', '')}円',
                    onPressed: () => notifier.setReceivedCash(
                      session.receivedCash + Money(v),
                    ),
                  ),
                _QuickButton(
                  label: 'ピッタリ',
                  onPressed: () => notifier.setReceivedCash(finalPrice),
                ),
                _QuickButton(
                  label: 'クリア',
                  onPressed: () => notifier.setReceivedCash(Money.zero),
                  destructive: true,
                ),
              ],
            ),
            const SizedBox(height: TofuTokens.space5),
          ],
          TofuButton(
            label: '会計確定',
            icon: Icons.check_circle,
            lordicon: 'check',
            size: TofuButtonSize.lg,
            fullWidth: true,
            loading: confirming,
            onPressed: (insufficient || session.items.isEmpty || confirming)
                ? null
                : onConfirm,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    this.highlight = false,
    this.tone = StatusIndicatorTone.neutral,
  });

  final String label;
  final String value;
  final bool highlight;
  final StatusIndicatorTone tone;

  @override
  Widget build(BuildContext context) {
    final Color bg = highlight ? TofuTokens.brandPrimary : TofuTokens.bgSurface;
    final Color labelColor = highlight
        ? TofuTokens.brandOnPrimary.withValues(alpha: 0.85)
        : TofuTokens.textTertiary;
    final Color valueColor = highlight
        ? TofuTokens.brandOnPrimary
        : (tone == StatusIndicatorTone.danger
              ? TofuTokens.dangerText
              : (tone == StatusIndicatorTone.success
                    ? TofuTokens.successText
                    : TofuTokens.textPrimary));
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      ),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TofuTextStyles.bodyMdBold.copyWith(color: labelColor),
          ),
          const Spacer(),
          Text(value, style: TofuTextStyles.h2.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TofuTokens.touchMin,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: destructive
              ? TofuTokens.dangerText
              : TofuTokens.textPrimary,
          side: BorderSide(
            color: destructive
                ? TofuTokens.dangerBorder
                : TofuTokens.borderDefault,
          ),
          padding: const EdgeInsets.symmetric(horizontal: TofuTokens.space5),
        ),
        child: Text(label, style: TofuTextStyles.bodyMdBold),
      ),
    );
  }
}
