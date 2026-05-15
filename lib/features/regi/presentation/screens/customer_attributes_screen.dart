import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/attribute_chip.dart';
import '../../../../core/ui/page_title.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/customer_attributes.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/enums/customer_attributes_enums.dart';
import '../../../../providers/repository_providers.dart';
import '../notifiers/checkout_session.dart';
import '../notifiers/regi_providers.dart';

/// 顧客属性入力画面（仕様書 §6.1.1、Figma `05-Register-CustomerAttr`）。
///
/// レジ担当の見立てで選ぶ前提のため、すべて任意（未選択 OK）。
///
/// レイアウト軸:
/// - landscape (>= 720dp, Figma 1024×768): 中央寄せ最大幅 960、padding
///   64h/16v、セクション間 16、フッタ右寄せ 3 ボタン
/// - portrait (< 720dp, Figma 375×812): フル幅、padding 20h/12v、
///   セクション間 12、フッタ 3 ボタン (スキップ / 戻る / 次へ)
///
/// 既存業務ロジック (`setCustomerAttributes` / `context.go`) はそのまま使用。
class CustomerAttributesScreen extends ConsumerWidget {
  const CustomerAttributesScreen({required this.order, super.key});

  /// 会計確定済みの Order。「次へ」で属性をこの Order に紐づけて保存。
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CheckoutSession session = ref.watch(checkoutSessionProvider);
    final CheckoutSessionNotifier notifier = ref.read(
      checkoutSessionProvider.notifier,
    );
    final CustomerAttributes attrs = session.customerAttributes;

    return LayoutBuilder(
      builder: (c, constraints) {
        final bool isWide = constraints.maxWidth >= 720;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const PageTitle(title: '顧客属性'),
                Expanded(
                  child: isWide
                      ? _LandscapeBody(
                          attrs: attrs,
                          notifier: notifier,
                          order: order,
                        )
                      : _PortraitBody(
                          attrs: attrs,
                          notifier: notifier,
                          order: order,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// landscape (>= 720dp) ボディ。Figma `64:84` を踏襲。
class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.attrs,
    required this.notifier,
    required this.order,
  });

  final CustomerAttributes attrs;
  final CheckoutSessionNotifier notifier;
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  TofuTokens.space11,
                  TofuTokens.space5,
                  TofuTokens.space11,
                  TofuTokens.space5,
                ),
                children: <Widget>[
                  const _Hint(),
                  const SizedBox(height: TofuTokens.space5),
                  _AgeSection(attrs: attrs, notifier: notifier),
                  const SizedBox(height: TofuTokens.space5),
                  _GenderSection(attrs: attrs, notifier: notifier),
                  const SizedBox(height: TofuTokens.space5),
                  _GroupSection(attrs: attrs, notifier: notifier),
                ],
              ),
            ),
            _FooterBar(
              order: order,
              attrs: attrs,
              padding: const EdgeInsets.fromLTRB(
                TofuTokens.space11,
                TofuTokens.space4,
                TofuTokens.space11,
                TofuTokens.space4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// portrait (< 720dp) ボディ。Figma `237:50` を踏襲。
class _PortraitBody extends StatelessWidget {
  const _PortraitBody({
    required this.attrs,
    required this.notifier,
    required this.order,
  });

  final CustomerAttributes attrs;
  final CheckoutSessionNotifier notifier;
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TofuTokens.space6,
              TofuTokens.space4,
              TofuTokens.space6,
              TofuTokens.space4,
            ),
            children: <Widget>[
              const _Hint(),
              const SizedBox(height: TofuTokens.space4),
              _AgeSection(attrs: attrs, notifier: notifier),
              const SizedBox(height: TofuTokens.space4),
              _GenderSection(attrs: attrs, notifier: notifier),
              const SizedBox(height: TofuTokens.space4),
              _GroupSection(attrs: attrs, notifier: notifier),
            ],
          ),
        ),
        _FooterBar(
          order: order,
          attrs: attrs,
          padding: const EdgeInsets.fromLTRB(
            TofuTokens.space5,
            TofuTokens.space3,
            TofuTokens.space5,
            TofuTokens.space3,
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Text(
      '見立てで選んでください（任意）',
      style: TofuTextStyles.bodyMd.copyWith(color: TofuTokens.textSecondary),
    );
  }
}

class _AgeSection extends StatelessWidget {
  const _AgeSection({required this.attrs, required this.notifier});

  final CustomerAttributes attrs;
  final CheckoutSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '年代',
      chips: <Widget>[
        for (final CustomerAge opt in CustomerAge.values)
          AttributeChip(
            label: opt.label,
            selected: attrs.age == opt,
            onTap: () => notifier.setCustomerAttributes(
              attrs.copyWith(
                age: attrs.age == opt ? null : opt,
                clearAge: attrs.age == opt,
              ),
            ),
          ),
      ],
    );
  }
}

class _GenderSection extends StatelessWidget {
  const _GenderSection({required this.attrs, required this.notifier});

  final CustomerAttributes attrs;
  final CheckoutSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '性別',
      chips: <Widget>[
        for (final CustomerGender opt in CustomerGender.values)
          AttributeChip(
            label: opt.label,
            selected: attrs.gender == opt,
            kind: AttributeChipKind.gender,
            onTap: () => notifier.setCustomerAttributes(
              attrs.copyWith(
                gender: attrs.gender == opt ? null : opt,
                clearGender: attrs.gender == opt,
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.attrs, required this.notifier});

  final CustomerAttributes attrs;
  final CheckoutSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '客層',
      chips: <Widget>[
        for (final CustomerGroup opt in CustomerGroup.values)
          AttributeChip(
            label: opt.label,
            selected: attrs.group == opt,
            kind: AttributeChipKind.segment,
            onTap: () => notifier.setCustomerAttributes(
              attrs.copyWith(
                group: attrs.group == opt ? null : opt,
                clearGroup: attrs.group == opt,
              ),
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.chips});

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: TofuTextStyles.h4),
        const SizedBox(height: TofuTokens.space3),
        Wrap(
          spacing: TofuTokens.space5,
          runSpacing: TofuTokens.space5,
          children: chips,
        ),
      ],
    );
  }
}

/// フッタの操作バー。Figma `64:123` / `237:89`。
///
/// 並び (右寄せ): スキップ (ghost) / 戻る (secondary) / 次へ (primary lg)。
class _FooterBar extends ConsumerWidget {
  const _FooterBar({
    required this.order,
    required this.attrs,
    required this.padding,
  });

  final Order order;
  final CustomerAttributes attrs;
  final EdgeInsets padding;

  Future<void> _save(WidgetRef ref) async {
    await ref
        .read(orderRepositoryProvider)
        .updateCustomerAttributes(order.id, attrs);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: TofuTokens.bgCanvas,
        border: Border(top: BorderSide(color: TofuTokens.borderSubtle)),
      ),
      child: Row(
        children: <Widget>[
          TofuButton(
            label: 'スキップ',
            variant: TofuButtonVariant.ghost,
            onPressed: () => context.go('/regi/done', extra: order),
          ),
          const Spacer(),
          TofuButton(
            label: '確定',
            icon: Icons.check,
            size: TofuButtonSize.lg,
            onPressed: () async {
              await _save(ref);
              if (!context.mounted) return;
              context.go(
                '/regi/done',
                extra: order.copyWith(customerAttributes: attrs),
              );
            },
          ),
        ],
      ),
    );
  }
}
