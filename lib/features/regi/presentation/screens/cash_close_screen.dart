import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/numeric_stepper.dart';
import '../../../../core/ui/status_chip.dart';
import '../../../../domain/entities/cash_drawer.dart';
import '../../../../domain/value_objects/cash_close_difference.dart';
import '../../../../domain/value_objects/daily_summary.dart';
import '../../../../domain/value_objects/denomination.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../providers/usecase_providers.dart';

/// レジ締め画面（仕様書 §6.4）。
class CashCloseScreen extends ConsumerStatefulWidget {
  const CashCloseScreen({super.key});

  @override
  ConsumerState<CashCloseScreen> createState() => _CashCloseScreenState();
}

class _CashCloseScreenState extends ConsumerState<CashCloseScreen> {
  Future<DailySummary>? _summaryFuture;
  Map<int, int> _actualCounts = <int, int>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final FeatureFlags flags =
        ref.read(featureFlagsProvider).value ?? FeatureFlags.allOff;
    setState(() {
      _summaryFuture = ref
          .read(cashCloseUseCaseProvider)
          .getDailySummary(flags: flags);
    });
  }

  CashDrawer _actualDrawer() {
    return CashDrawer(<Denomination, int>{
      for (final Denomination d in Denomination.all)
        d: _actualCounts[d.yen] ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final FeatureFlags flags =
        ref.watch(featureFlagsProvider).value ?? FeatureFlags.allOff;

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppBar(
        title: const Text('レジ締め'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '再計算',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<DailySummary>(
          future: _summaryFuture,
          builder: (c, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final DailySummary s = snap.data!;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(TofuTokens.space5),
                  children: <Widget>[
                    if (s.hasUnsynced) ...<Widget>[
                      StatusChip(
                        label:
                            '未同期の注文が ${s.unsyncedCount} 件残っています。'
                            'オンラインに復帰するとまとめて送信されます。',
                        icon: Icons.cloud_off,
                        tone: TofuStatusTone.warning,
                      ),
                      const SizedBox(height: TofuTokens.space5),
                    ],
                    _SalesSummaryCard(summary: s),
                    if (flags.cashManagement) ...<Widget>[
                      const SizedBox(height: TofuTokens.space7),
                      _CashReconciliationSection(
                        theoretical: s.theoreticalDrawer ?? CashDrawer.empty(),
                        actualCounts: _actualCounts,
                        onChanged: (yen, count) {
                          setState(() {
                            _actualCounts = Map<int, int>.from(_actualCounts)
                              ..[yen] = count;
                          });
                        },
                      ),
                      const SizedBox(height: TofuTokens.space5),
                      _DiffCard(
                        difference: ref
                            .read(cashCloseUseCaseProvider)
                            .computeDifference(
                              theoretical:
                                  s.theoreticalDrawer ?? CashDrawer.empty(),
                              actual: _actualDrawer(),
                            ),
                      ),
                    ],
                    const SizedBox(height: TofuTokens.space11),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SalesSummaryCard extends StatelessWidget {
  const _SalesSummaryCard({required this.summary});
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space7),
      decoration: BoxDecoration(
        color: TofuTokens.brandPrimary,
        borderRadius: BorderRadius.circular(TofuTokens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '本日の売上',
            style: TofuTextStyles.bodyLgBold.copyWith(
              color: TofuTokens.brandOnPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: TofuTokens.space3),
          Text(
            TofuFormat.yen(summary.totalSales),
            style: TofuTextStyles.numberDisplay.copyWith(
              color: TofuTokens.brandOnPrimary,
              fontSize: 56,
            ),
          ),
          const SizedBox(height: TofuTokens.space5),
          Row(
            children: <Widget>[
              _Stat(label: '注文件数', value: '${summary.orderCount}'),
              const SizedBox(width: TofuTokens.space5),
              _Stat(label: '取消件数', value: '${summary.cancelledCount}'),
              const SizedBox(width: TofuTokens.space5),
              _Stat(label: '未同期', value: '${summary.unsyncedCount}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: TofuTokens.space3,
          horizontal: TofuTokens.space4,
        ),
        decoration: BoxDecoration(
          color: TofuTokens.brandOnPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TofuTextStyles.captionBold.copyWith(
                color: TofuTokens.brandOnPrimary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TofuTextStyles.h3.copyWith(
                color: TofuTokens.brandOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashReconciliationSection extends StatelessWidget {
  const _CashReconciliationSection({
    required this.theoretical,
    required this.actualCounts,
    required this.onChanged,
  });

  final CashDrawer theoretical;
  final Map<int, int> actualCounts;
  final void Function(int yen, int count) onChanged;

  @override
  Widget build(BuildContext context) {
    final List<Denomination> denoms = Denomination.all.reversed.toList();
    return Container(
      padding: const EdgeInsets.all(TofuTokens.space5),
      decoration: BoxDecoration(
        color: TofuTokens.bgCanvas,
        borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
        border: Border.all(color: TofuTokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('金種照合（理論値 vs 実測値）', style: TofuTextStyles.h4),
          const SizedBox(height: TofuTokens.space2),
          Text(
            '実際にレジに残っている枚数を入力してください。',
            style: TofuTextStyles.bodySm.copyWith(
              color: TofuTokens.textTertiary,
            ),
          ),
          const SizedBox(height: TofuTokens.space5),
          for (final Denomination d in denoms) ...<Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 80,
                  child: Text('¥${d.yen}', style: TofuTextStyles.bodyLgBold),
                ),
                const SizedBox(width: TofuTokens.space3),
                Expanded(
                  child: Text(
                    '理論 ${theoretical.countOf(d)} 枚',
                    style: TofuTextStyles.bodySm.copyWith(
                      color: TofuTokens.textTertiary,
                    ),
                  ),
                ),
                NumericStepper(
                  value: actualCounts[d.yen] ?? 0,
                  onChanged: (v) => onChanged(d.yen, v),
                  suffix: '枚',
                  compact: true,
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

class _DiffCard extends StatelessWidget {
  const _DiffCard({required this.difference});
  final CashCloseDifference difference;

  @override
  Widget build(BuildContext context) {
    final TofuStatusTone tone = difference.isZero
        ? TofuStatusTone.success
        : (difference.isShort ? TofuStatusTone.danger : TofuStatusTone.warning);
    final String label = difference.isZero
        ? '差額なし（一致）'
        : (difference.isShort ? '不足' : '余り');
    return StatusChip(
      label: '$label  ${TofuFormat.yen(difference.amountDiff.abs())}',
      icon: difference.isZero
          ? Icons.check_circle
          : (difference.isShort ? Icons.error : Icons.warning_amber),
      tone: tone,
    );
  }
}
