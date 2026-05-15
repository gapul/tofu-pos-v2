import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/entities/customer_attributes.dart';
import '../../../../domain/enums/customer_attributes_enums.dart';
import '../notifiers/checkout_session.dart';
import '../notifiers/regi_providers.dart';

/// 顧客属性入力画面（仕様書 §6.1.1）。
///
/// レジ担当の見立てで選ぶ前提のため、すべて任意（未選択 OK）。
class CustomerAttributesScreen extends ConsumerWidget {
  const CustomerAttributesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CheckoutSession session = ref.watch(checkoutSessionProvider);
    final CheckoutSessionNotifier notifier = ref.read(
      checkoutSessionProvider.notifier,
    );
    final CustomerAttributes attrs = session.customerAttributes;

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppHeader(
        title: '顧客属性',
        upcomingTicket: ref.watch(upcomingTicketProvider).value,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: '戻る',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(TofuTokens.space7),
              children: <Widget>[
                Text(
                  '見立てで選んでください（任意）',
                  style: TofuTextStyles.bodyMd.copyWith(
                    color: TofuTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: TofuTokens.space7),
                _Section<CustomerAge>(
                  title: '年代',
                  options: CustomerAge.values,
                  selected: attrs.age,
                  labelOf: (a) => a.label,
                  onChanged: (a) => notifier.setCustomerAttributes(
                    attrs.copyWith(age: a, clearAge: a == null),
                  ),
                ),
                const SizedBox(height: TofuTokens.space7),
                _Section<CustomerGender>(
                  title: '性別',
                  options: CustomerGender.values,
                  selected: attrs.gender,
                  labelOf: (g) => g.label,
                  onChanged: (g) =>
                      notifier.setCustomerAttributes(
                        attrs.copyWith(gender: g, clearGender: g == null),
                      ),
                ),
                const SizedBox(height: TofuTokens.space7),
                _Section<CustomerGroup>(
                  title: '客層',
                  options: CustomerGroup.values,
                  selected: attrs.group,
                  labelOf: (g) => g.label,
                  onChanged: (g) =>
                      notifier.setCustomerAttributes(
                        attrs.copyWith(group: g, clearGroup: g == null),
                      ),
                ),
                const SizedBox(height: TofuTokens.space11),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TofuButton(
                        label: 'スキップ',
                        variant: TofuButtonVariant.ghost,
                        onPressed: () => context.go('/regi/products'),
                      ),
                    ),
                    const SizedBox(width: TofuTokens.space5),
                    Expanded(
                      flex: 2,
                      child: TofuButton(
                        label: '次へ',
                        icon: Icons.arrow_forward,
                        size: TofuButtonSize.lg,
                        onPressed: () => context.go('/regi/products'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section<T> extends StatelessWidget {
  const _Section({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final String title;
  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: TofuTextStyles.h4),
        const SizedBox(height: TofuTokens.space4),
        Wrap(
          spacing: TofuTokens.space3,
          runSpacing: TofuTokens.space3,
          children: <Widget>[
            for (final T opt in options)
              ChoiceChip(
                label: Text(labelOf(opt)),
                selected: selected == opt,
                showCheckmark: false,
                onSelected: (sel) => onChanged(sel ? opt : null),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: TofuTokens.space4,
                  vertical: TofuTokens.space3,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
