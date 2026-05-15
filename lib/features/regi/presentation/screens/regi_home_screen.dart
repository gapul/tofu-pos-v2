import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/status_chip.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../domain/value_objects/ticket_number.dart';
import '../../../../providers/settings_providers.dart';
import '../notifiers/checkout_session.dart';
import '../notifiers/regi_providers.dart';

/// レジホーム画面（仕様書 §6.1）。
///
/// 「次のお客様」ボタンが顧客属性入力（フラグオン時）または商品選択へ進む。
class RegiHomeScreen extends ConsumerWidget {
  const RegiHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FeatureFlags> flagsAsync = ref.watch(featureFlagsProvider);
    final AsyncValue<TicketNumber?> upcoming = ref.watch(
      upcomingTicketProvider,
    );

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppHeader(
        title: 'レジ',
        upcomingTicket: upcoming.value,
        actions: <Widget>[
          IconButton(
            tooltip: '注文履歴',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/regi/history'),
          ),
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TofuTokens.space7),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  upcoming.when(
                    data: (next) => _NextTicketHero(next: next),
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => StatusChip(
                      label: '整理券プールの読み込みに失敗: $e',
                      icon: Icons.error_outline,
                      tone: TofuStatusTone.danger,
                    ),
                  ),
                  const SizedBox(height: TofuTokens.space8),
                  flagsAsync.when(
                    data: (flags) =>
                        _StartButton(flags: flags, ref: ref),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('$e'),
                  ),
                  const SizedBox(height: TofuTokens.space7),
                  const _SecondaryGrid(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextTicketHero extends StatelessWidget {
  const _NextTicketHero({required this.next});
  final TicketNumber? next;

  @override
  Widget build(BuildContext context) {
    if (next == null) {
      return const StatusChip(
        label: '整理券プール枯渇 — 提供完了/取消で番号が解放されるまで新規会計不可',
        icon: Icons.warning_amber,
        tone: TofuStatusTone.danger,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space11,
        vertical: TofuTokens.space7,
      ),
      decoration: BoxDecoration(
        color: TofuTokens.brandPrimarySubtle,
        borderRadius: BorderRadius.circular(TofuTokens.radius2xl),
        border: Border.all(color: TofuTokens.brandPrimaryBorder),
      ),
      child: Column(
        children: <Widget>[
          const Text('次回の整理券番号', style: TofuTextStyles.bodyLgBold),
          const SizedBox(height: TofuTokens.space3),
          Text(
            next!.toString(),
            style: TofuTextStyles.numberDisplay.copyWith(
              color: TofuTokens.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.flags, required this.ref});
  final FeatureFlags flags;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return TofuButton(
      label: '次のお客様',
      icon: Icons.arrow_forward,
      size: TofuButtonSize.lg,
      fullWidth: true,
      onPressed: () {
        ref.read(checkoutSessionProvider.notifier).reset();
        if (flags.customerAttributes) {
          unawaited(context.push('/regi/customer'));
        } else {
          unawaited(context.push('/regi/products'));
        }
      },
    );
  }
}

class _SecondaryGrid extends StatelessWidget {
  const _SecondaryGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TofuTokens.space5,
      runSpacing: TofuTokens.space5,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _ShortcutCard(
          icon: Icons.history,
          label: '注文履歴',
          onTap: () => context.push('/regi/history'),
        ),
        _ShortcutCard(
          icon: Icons.inventory_2,
          label: '商品マスタ',
          onTap: () => context.push('/regi/products/master'),
        ),
        _ShortcutCard(
          icon: Icons.account_balance_wallet,
          label: 'レジ締め',
          onTap: () => context.push('/regi/cash-close'),
        ),
        _ShortcutCard(
          icon: Icons.settings,
          label: '設定',
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 120,
      child: Material(
        color: TofuTokens.bgSurface,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(TofuTokens.space5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 36, color: TofuTokens.brandPrimary),
                const SizedBox(height: TofuTokens.space3),
                Text(label, style: TofuTextStyles.bodyMdBold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
