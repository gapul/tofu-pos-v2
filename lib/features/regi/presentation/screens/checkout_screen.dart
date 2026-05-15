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
import '../../../../core/ui/page_title.dart';
import '../../../../core/ui/quick_amount_btn.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../core/ui/top_snack.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/services/change_suggestion.dart';
import '../../../../domain/value_objects/denomination.dart';
import '../../../../domain/value_objects/discount.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../providers/settings_providers.dart';
import '../notifiers/checkout_session.dart';
import '../notifiers/regi_providers.dart';

/// 会計画面（仕様書 §6.1.3 / §9.3 / Figma `04-Register-Payment` landscape 436:494）。
///
/// レイアウト（landscape, Figma 完全準拠）:
///   - 左ペイン (560w, bgCanvas): タイトル「お会計」+ サマリーカード
///     （注文行 / 小計 / 割引 / 請求金額 ハイライト）+ 割引・割増セクション
///     （ステッパー -/+ + 円/% トグル）
///   - 右ペイン (flex, bgSurface): 預り金 + お釣り 合体カード (Display/S 48)
///     + 「クイック金額」+ 2 列 +100/+500/+1000/+5000/+10000/ピッタリ
///     + 「会計確定 → 整理券N」primary lg full-width
///
/// 業務ロジック (`CheckoutConfirmController`) はそのまま流用。
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  void _showSnack(BuildContext context, String message, {Color? bg}) {
    TopSnack.show(context, message, color: bg);
  }

  void _handleConfirmResult(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Order?>? previous,
    AsyncValue<Order?> next,
  ) {
    next.whenOrNull(
      data: (order) {
        if (order != null && previous?.value != order) {
          unawaited(HapticFeedback.heavyImpact());
          // 顧客属性入力フラグ ON のときは、お釣り受け取り後に顧客属性を
          // 入力させてから完了画面へ。OFF のときは直接完了画面へ。
          final FeatureFlags flags =
              ref.read(featureFlagsProvider).value ?? FeatureFlags.allOff;
          if (flags.customerAttributes) {
            context.go('/regi/customer', extra: order);
          } else {
            context.go('/regi/done', extra: order);
          }
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
          context.go('/');
          return;
        }
        if (error is TicketPoolExhaustedException) {
          _showSnack(context, error.message);
          return;
        }
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
    final int? upcomingTicket = ref.watch(upcomingTicketProvider).value?.value;

    ref.listen<AsyncValue<Order?>>(
      checkoutConfirmControllerProvider,
      (prev, next) => _handleConfirmResult(context, ref, prev, next),
    );

    Future<void> onConfirm() async {
      try {
        await ref.read(checkoutConfirmControllerProvider.notifier).confirm();
      } catch (_) {
        // listen 側で表示済。
      }
    }

    return LayoutBuilder(
      builder: (c, constraints) {
        final bool wide = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: TofuTokens.bgCanvas,
          appBar: AppHeader(
            title: 'レジ',
            upcomingTicket: ref.watch(upcomingTicketProvider).value,
            onTicketTap: () => context.push('/regi/calling'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
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
                    upcomingTicket: upcomingTicket,
                    onConfirm: onConfirm,
                  )
                : _PortraitLayout(
                    session: session,
                    notifier: notifier,
                    flags: flags,
                    confirming: confirming,
                    upcomingTicket: upcomingTicket,
                    onConfirm: onConfirm,
                  ),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Landscape (Figma 436:494): 左 560w / 右 flex の 2 ペイン
// ===========================================================================
class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({
    required this.session,
    required this.notifier,
    required this.flags,
    required this.confirming,
    required this.upcomingTicket,
    required this.onConfirm,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final FeatureFlags flags;
  final bool confirming;
  final int? upcomingTicket;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: 560,
          child: _LeftPane(session: session, notifier: notifier, flags: flags),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: TofuTokens.bgSurface,
              border: Border(
                left: BorderSide(color: TofuTokens.borderSubtle),
              ),
            ),
            child: _RightPane(
              session: session,
              notifier: notifier,
              flags: flags,
              confirming: confirming,
              upcomingTicket: upcomingTicket,
              onConfirm: onConfirm,
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Portrait: 縦に左 → 右の順
// ===========================================================================
class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({
    required this.session,
    required this.notifier,
    required this.flags,
    required this.confirming,
    required this.upcomingTicket,
    required this.onConfirm,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final FeatureFlags flags;
  final bool confirming;
  final int? upcomingTicket;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        _LeftPane(
          session: session,
          notifier: notifier,
          flags: flags,
          scrollable: false,
        ),
        Container(
          decoration: const BoxDecoration(
            color: TofuTokens.bgSurface,
            border: Border(top: BorderSide(color: TofuTokens.borderSubtle)),
          ),
          child: _RightPane(
            session: session,
            notifier: notifier,
            flags: flags,
            confirming: confirming,
            upcomingTicket: upcomingTicket,
            onConfirm: onConfirm,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// 左ペイン: PageTitle + Summary + Discount
// ===========================================================================
class _LeftPane extends StatelessWidget {
  const _LeftPane({
    required this.session,
    required this.notifier,
    required this.flags,
    this.scrollable = true,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final FeatureFlags flags;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    const EdgeInsets pad = EdgeInsets.fromLTRB(
      TofuTokens.space8,
      TofuTokens.space7,
      TofuTokens.space7,
      TofuTokens.space7,
    );
    final List<Widget> children = <Widget>[
      const PageTitle(title: 'お会計', padding: EdgeInsets.zero),
      const SizedBox(height: TofuTokens.space5),
      _SummaryCard(session: session),
      const SizedBox(height: TofuTokens.space5),
      _DiscountSection(session: session, notifier: notifier),
      if (flags.cashManagement && session.changeCash.yen > 0) ...<Widget>[
        const SizedBox(height: TofuTokens.space5),
        _ChangeSuggestionCard(changeYen: session.changeCash.yen),
      ],
      const SizedBox(height: TofuTokens.space11),
    ];
    if (scrollable) {
      return ListView(padding: pad, children: children);
    }
    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// ===========================================================================
// サマリーカード (Figma 70:88): 注文行 / 小計 / 割引 / 請求金額(highlight)
// ===========================================================================
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.session});
  final CheckoutSession session;

  @override
  Widget build(BuildContext context) {
    final Money subtotal = session.totalPrice;
    final Money discount = subtotal - session.discount.applyTo(subtotal);
    final Money finalPrice = session.finalPrice;
    final bool hasDiscount = !discount.isZero;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space7,
        vertical: TofuTokens.space6,
      ),
      decoration: BoxDecoration(
        color: TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: TofuTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 注文行（Figma にはないが既存テストとロジック的に表示）
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
                    width: 96,
                    child: Text(
                      TofuFormat.yen(it.subtotal),
                      textAlign: TextAlign.right,
                      style: TofuTextStyles.bodyMdBold,
                    ),
                  ),
                ],
              ),
            ),
          if (session.items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: TofuTokens.space3),
              child: Divider(height: 1, color: TofuTokens.borderSubtle),
            ),
          _SummaryRow(
            label: '小計',
            value: TofuFormat.yen(subtotal),
          ),
          if (hasDiscount) ...<Widget>[
            const SizedBox(height: TofuTokens.space4),
            _SummaryRow(
              label: '割引',
              value: '-${TofuFormat.yen(discount)}',
              valueColor: TofuTokens.dangerText,
            ),
          ],
          const SizedBox(height: TofuTokens.space4),
          const Divider(height: 1, color: TofuTokens.borderSubtle),
          const SizedBox(height: TofuTokens.space4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '請求金額',
                style: TofuTextStyles.bodySm.copyWith(
                  color: TofuTokens.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                TofuFormat.yen(finalPrice),
                style: TofuTextStyles.h1.copyWith(
                  color: TofuTokens.brandPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          label,
          style: TofuTextStyles.bodySm.copyWith(
            color: TofuTokens.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TofuTextStyles.bodyLg.copyWith(
            color: valueColor ?? TofuTokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// 割引・割増セクション (Figma 70:99): -/+ ステッパー + 円/% トグル
// ===========================================================================
class _DiscountSection extends StatefulWidget {
  const _DiscountSection({required this.session, required this.notifier});
  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;

  @override
  State<_DiscountSection> createState() => _DiscountSectionState();
}

class _DiscountSectionState extends State<_DiscountSection> {
  late bool _isPercent;
  late int _signedValue; // negative = 割引, positive = 割増

  @override
  void initState() {
    super.initState();
    final Discount d = widget.session.discount;
    if (d is AmountDiscount) {
      _isPercent = false;
      _signedValue = d.amount.yen; // 負 = 割引, 正 = 割増
    } else if (d is PercentDiscount) {
      _isPercent = true;
      _signedValue = d.percent;
    } else {
      _isPercent = false;
      _signedValue = 0;
    }
  }

  void _emit() {
    if (_isPercent) {
      widget.notifier.setDiscount(PercentDiscount(_signedValue));
    } else {
      widget.notifier.setDiscount(AmountDiscount(Money(_signedValue)));
    }
  }

  void _bump(int delta) {
    setState(() => _signedValue += delta);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final String displayValue = _signedValue == 0
        ? '0'
        : (_signedValue > 0 ? '+$_signedValue' : '$_signedValue');
    final Color valueColor = _signedValue < 0
        ? TofuTokens.dangerText
        : (_signedValue > 0 ? TofuTokens.successText : TofuTokens.textPrimary);
    final int step = _isPercent ? 1 : 100;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space6,
        vertical: TofuTokens.space5,
      ),
      decoration: BoxDecoration(
        color: TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: TofuTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '割引・割増',
            style: TofuTextStyles.bodySm.copyWith(
              color: TofuTokens.textSecondary,
            ),
          ),
          const SizedBox(height: TofuTokens.space4),
          Row(
            children: <Widget>[
              // -/+ ステッパー
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: TofuTokens.bgCanvas,
                    borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
                    border: Border.all(color: TofuTokens.borderDefault),
                  ),
                  child: Row(
                    children: <Widget>[
                      _StepperButton(
                        icon: Icons.remove,
                        onTap: () => _bump(-step),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              displayValue,
                              style: TofuTextStyles.h4.copyWith(
                                color: valueColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _StepperButton(
                        icon: Icons.add,
                        onTap: () => _bump(step),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: TofuTokens.space3),
              // 円/% トグル
              Container(
                padding: const EdgeInsets.all(TofuTokens.space2),
                decoration: BoxDecoration(
                  color: TofuTokens.bgMuted,
                  borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
                ),
                child: Row(
                  children: <Widget>[
                    _ModeChip(
                      label: '円',
                      selected: !_isPercent,
                      onTap: () {
                        setState(() => _isPercent = false);
                        _emit();
                      },
                    ),
                    _ModeChip(
                      label: '％',
                      selected: _isPercent,
                      onTap: () {
                        setState(() => _isPercent = true);
                        _emit();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: 24, color: TofuTokens.textPrimary),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TofuTokens.brandPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(TofuTokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(TofuTokens.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space3,
          ),
          child: Text(
            label,
            style: TofuTextStyles.bodyMd.copyWith(
              color: selected
                  ? TofuTokens.brandOnPrimary
                  : TofuTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// 金種管理セクション（cashManagement フラグ ON 時のみ）
// ===========================================================================
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
        color: TofuTokens.bgSurface,
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
                  child: Text('${d.yen}円', style: TofuTextStyles.bodyLgBold),
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

// ===========================================================================
// 右ペイン (Figma 70:116): 預り金＋お釣り合体カード + クイック金額 + 会計確定
// ===========================================================================
class _RightPane extends StatelessWidget {
  const _RightPane({
    required this.session,
    required this.notifier,
    required this.flags,
    required this.confirming,
    required this.upcomingTicket,
    required this.onConfirm,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final FeatureFlags flags;
  final bool confirming;
  final int? upcomingTicket;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final Money finalPrice = session.finalPrice;
    final Money change = session.changeCash;
    final bool insufficient = change.isNegative;
    final String confirmLabel = upcomingTicket != null
        ? '会計確定 → 整理券$upcomingTicket'
        : '会計確定';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TofuTokens.space7,
        TofuTokens.space7,
        TofuTokens.space8,
        TofuTokens.space7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 預り金 + お釣り 合体カード（Figma 70:117）
          _CashAndChangeCard(
            session: session,
            insufficient: insufficient,
            change: change,
          ),
          // 金種管理ON時：預り金（金種別）ステッパー
          if (flags.cashManagement) ...<Widget>[
            const SizedBox(height: TofuTokens.space4),
            _CashManagementSection(session: session, notifier: notifier),
          ],
          const SizedBox(height: TofuTokens.space5),
          if (!flags.cashManagement) ...<Widget>[
            Text(
              'クイック金額',
              style: TofuTextStyles.bodySm.copyWith(
                color: TofuTokens.textSecondary,
              ),
            ),
            const SizedBox(height: TofuTokens.space4),
            _QuickAmountGrid(
              session: session,
              notifier: notifier,
              finalPrice: finalPrice,
            ),
            const SizedBox(height: TofuTokens.space5),
          ] else ...<Widget>[
            const SizedBox(height: TofuTokens.space5),
          ],
          const SizedBox(height: TofuTokens.space7),
          TofuButton(
            label: confirmLabel,
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

// ===========================================================================
// 預り金 + お釣り 合体カード (Figma 70:117)
//   - bgCanvas / radiusLg / px20 py16
//   - 「預り金」caption + 48px display 値
//   - 区切らず下に「お釣り」caption + Number/Md (24) 値
// ===========================================================================
class _CashAndChangeCard extends StatelessWidget {
  const _CashAndChangeCard({
    required this.session,
    required this.insufficient,
    required this.change,
  });

  final CheckoutSession session;
  final bool insufficient;
  final Money change;

  @override
  Widget build(BuildContext context) {
    final Color changeColor = insufficient
        ? TofuTokens.dangerText
        : (change.isZero ? TofuTokens.textTertiary : TofuTokens.successText);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space6,
        vertical: TofuTokens.space5,
      ),
      decoration: BoxDecoration(
        color: TofuTokens.bgCanvas,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '預り金',
            style: TofuTextStyles.caption.copyWith(
              color: TofuTokens.textSecondary,
            ),
          ),
          const SizedBox(height: TofuTokens.space3),
          Text(
            TofuFormat.yen(session.receivedCash),
            style: TofuTextStyles.displayS.copyWith(
              color: TofuTokens.textPrimary,
              height: 56 / 48,
            ),
          ),
          const SizedBox(height: TofuTokens.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                insufficient ? '不足' : 'お釣り',
                style: TofuTextStyles.caption.copyWith(
                  color: TofuTokens.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                TofuFormat.yen(change.abs()),
                style: TofuTextStyles.numberMd.copyWith(color: changeColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// クイック金額 2 列グリッド (Figma 70:124):
//   +100 / +500 / +1000 / +5000 / +10000 / ピッタリ
// ===========================================================================
class _QuickAmountGrid extends StatelessWidget {
  const _QuickAmountGrid({
    required this.session,
    required this.notifier,
    required this.finalPrice,
  });

  final CheckoutSession session;
  final CheckoutSessionNotifier notifier;
  final Money finalPrice;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = <Widget>[
      for (final int v in <int>[100, 500, 1000, 5000, 10000])
        QuickAmountBtn(
          amount: v,
          label: '+${TofuFormat.yenInt(v)}',
          onPressed: () =>
              notifier.setReceivedCash(session.receivedCash + Money(v)),
        ),
      _PerfectButton(
        onPressed: () => notifier.setReceivedCash(finalPrice),
      ),
    ];
    return LayoutBuilder(
      builder: (c, constraints) {
        const double spacing = TofuTokens.space3;
        final double itemW = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final Widget t in tiles) SizedBox(width: itemW, child: t),
          ],
        );
      },
    );
  }
}

class _PerfectButton extends StatelessWidget {
  const _PerfectButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TofuTokens.bgCanvas,
      borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: TofuTokens.touchPrimary),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
            border: Border.all(color: TofuTokens.borderDefault),
          ),
          alignment: Alignment.center,
          child: Text(
            'ピッタリ',
            style: TofuTextStyles.bodyLgBold.copyWith(
              color: TofuTokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// お釣り提案カード（仕様書 §6.3）
//   金種管理 ON 時に、お釣りを最少枚数で渡せる金種組合せを表示する。
//   将来的にレジ内在庫を考慮するときは [stock] パラメータを追加で渡す。
// ===========================================================================
class _ChangeSuggestionCard extends StatelessWidget {
  const _ChangeSuggestionCard({required this.changeYen});

  final int changeYen;

  @override
  Widget build(BuildContext context) {
    final ChangeSuggestion s = ChangeSuggestion.compute(changeYen: changeYen);
    if (s.bills.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<MapEntry<int, int>> entries = s.bills.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space5,
        vertical: TofuTokens.space4,
      ),
      decoration: BoxDecoration(
        color: TofuTokens.bgMuted,
        borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.recommend,
                size: 16,
                color: TofuTokens.textSecondary,
              ),
              const SizedBox(width: TofuTokens.space2),
              Text(
                'お釣りの渡し方（最少 ${s.totalCount} 枚）',
                style: TofuTextStyles.captionBold.copyWith(
                  color: TofuTokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: TofuTokens.space3),
          Wrap(
            spacing: TofuTokens.space3,
            runSpacing: TofuTokens.space2,
            children: <Widget>[
              for (final MapEntry<int, int> e in entries)
                _DenominationChip(yen: e.key, count: e.value),
            ],
          ),
        ],
      ),
    );
  }
}

class _DenominationChip extends StatelessWidget {
  const _DenominationChip({required this.yen, required this.count});

  final int yen;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space3,
        vertical: TofuTokens.space2,
      ),
      decoration: BoxDecoration(
        color: TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusSm),
        border: Border.all(color: TofuTokens.borderSubtle),
      ),
      child: RichText(
        text: TextSpan(
          style: TofuTextStyles.bodySm.copyWith(color: TofuTokens.textPrimary),
          children: <TextSpan>[
            TextSpan(text: '$yen円 '),
            TextSpan(
              text: '×$count',
              style: TofuTextStyles.bodySmBold.copyWith(
                color: TofuTokens.brandPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
