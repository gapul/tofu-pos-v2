import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/export/csv_export_file_service.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/alert_banner.dart';
import '../../../../core/ui/app_header.dart';
import '../../../../core/ui/format.dart';
import '../../../../core/ui/num_stepper.dart';
import '../../../../core/ui/page_title.dart';
import '../../../../core/ui/pane_title.dart';
import '../../../../core/ui/status_indicator.dart';
import '../../../../core/ui/tofu_button.dart';
import '../../../../core/ui/tofu_icon.dart';
import '../../../../core/ui/top_snack.dart';
import '../../../../domain/entities/cash_drawer.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/value_objects/cash_close_difference.dart';
import '../../../../domain/value_objects/daily_summary.dart';
import '../../../../domain/value_objects/denomination.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../providers/usecase_providers.dart';

/// レジ締め画面（Figma `12-Register-DailyClose` / 仕様書 §6.4）。
///
/// landscape: 左ペイン「本日の売上 + 未同期 alert + アクション」、
///            右ペイン「金種照合テーブル（理論値 / 実測値 / 差）」。
class CashCloseScreen extends ConsumerStatefulWidget {
  const CashCloseScreen({super.key});

  @override
  ConsumerState<CashCloseScreen> createState() => _CashCloseScreenState();
}

class _CashCloseScreenState extends ConsumerState<CashCloseScreen> {
  Future<DailySummary>? _summaryFuture;
  Map<int, int> _actualCounts = <int, int>{};
  bool _csvBusy = false;

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

  Future<void> _exportCsv() async {
    setState(() => _csvBusy = true);
    try {
      final List<Order> orders = await ref
          .read(orderRepositoryProvider)
          .findAll();
      final shopId =
          (await ref.read(settingsRepositoryProvider).getShopId())?.value ??
          'unknown_shop';
      final String path = await CsvExportFileService().writeAndShare(
        orders: orders,
        shopId: shopId,
      );
      if (!mounted) {
        return;
      }
      TopSnack.show(context, 'CSV を共有しました ($path)');
    } catch (e) {
      if (!mounted) {
        return;
      }
      TopSnack.show(context, 'エクスポートに失敗: $e', color: TofuTokens.dangerBgStrong);
    } finally {
      if (mounted) {
        setState(() => _csvBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FeatureFlags flags =
        ref.watch(featureFlagsProvider).value ?? FeatureFlags.allOff;

    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      appBar: AppHeader(
        title: 'レジ',
        leading: IconButton(
          icon: const TofuIcon(TofuIconName.chevronLeft),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
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
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const PageTitle(title: 'レジ締め'),
            Expanded(
              child: FutureBuilder<DailySummary>(
                future: _summaryFuture,
                builder: (c, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final DailySummary s = snap.data!;
                  return LayoutBuilder(
                    builder: (c, constraints) {
                      final bool wide = constraints.maxWidth >= 720;
                      final Widget left = _SummaryPane(
                        summary: s,
                        csvBusy: _csvBusy,
                        onCsv: _exportCsv,
                      );
                      final Widget? right = flags.cashManagement
                          ? _CashReconcilePane(
                              theoretical:
                                  s.theoreticalDrawer ?? CashDrawer.empty(),
                              actualCounts: _actualCounts,
                              onChanged: (yen, count) {
                                setState(() {
                                  _actualCounts = Map<int, int>.from(
                                    _actualCounts,
                                  )..[yen] = count;
                                });
                              },
                              difference: ref
                                  .read(cashCloseUseCaseProvider)
                                  .computeDifference(
                                    theoretical:
                                        s.theoreticalDrawer ??
                                        CashDrawer.empty(),
                                    actual: _actualDrawer(),
                                  ),
                            )
                          : null;

                      if (wide && right != null) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(flex: 5, child: left),
                            Expanded(flex: 6, child: right),
                          ],
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.all(TofuTokens.space5),
                        children: <Widget>[
                          left,
                          if (right != null) ...<Widget>[
                            const SizedBox(height: TofuTokens.space7),
                            right,
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 左ペイン (Figma 81:186): 本日のレジ締めヘッダ + 売上 + 未同期 + アクション。
// ---------------------------------------------------------------------------
class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
    required this.summary,
    required this.csvBusy,
    required this.onCsv,
  });

  final DailySummary summary;
  final bool csvBusy;
  final VoidCallback onCsv;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TofuTokens.bgCanvas,
      padding: const EdgeInsets.all(TofuTokens.space7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PaneTitle(
            title: '本日のレジ締め',
            subtitle: '取消除いた請求合計・件数・差額を確認します',
          ),
          const SizedBox(height: TofuTokens.space5),
          _SalesCard(summary: summary),
          if (summary.hasUnsynced) ...<Widget>[
            const SizedBox(height: TofuTokens.space5),
            AlertBanner(
              variant: AlertBannerVariant.warning,
              title: '未同期 ${summary.unsyncedCount}件',
              message: '通信復旧後に自動再送されます。営業終了後もオフラインの場合はCSV書き出しを推奨します。',
            ),
          ],
          const SizedBox(height: TofuTokens.space7),
          Row(
            children: <Widget>[
              Expanded(
                child: TofuButton(
                  label: 'CSV書き出し',
                  icon: Icons.file_download,
                  variant: TofuButtonVariant.secondary,
                  loading: csvBusy,
                  onPressed: csvBusy ? null : onCsv,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 売上カード (Figma 81:189): brandPrimary 背景 + 大型数値 + 3 KPI ピル。
// ---------------------------------------------------------------------------
class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.summary});
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final int avg = summary.orderCount == 0
        ? 0
        : (summary.totalSales.yen / summary.orderCount).round();
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
            '本日売上',
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
              _Pill(label: '注文数', value: '${summary.orderCount}件'),
              const SizedBox(width: TofuTokens.space4),
              _Pill(label: '取消', value: '${summary.cancelledCount}件'),
              const SizedBox(width: TofuTokens.space4),
              _Pill(label: '平均単価', value: TofuFormat.yenInt(avg)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});
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
              style: TofuTextStyles.h4.copyWith(
                color: TofuTokens.brandOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 右ペイン (Figma 81:212): 金種照合テーブル + 差額 status。
// ---------------------------------------------------------------------------
class _CashReconcilePane extends StatelessWidget {
  const _CashReconcilePane({
    required this.theoretical,
    required this.actualCounts,
    required this.onChanged,
    required this.difference,
  });

  final CashDrawer theoretical;
  final Map<int, int> actualCounts;
  final void Function(int yen, int count) onChanged;
  final CashCloseDifference difference;

  @override
  Widget build(BuildContext context) {
    final List<Denomination> denoms = Denomination.all.reversed.toList();
    return Container(
      color: TofuTokens.bgSurface,
      padding: const EdgeInsets.all(TofuTokens.space7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PaneTitle(
            title: '金種照合',
            subtitle: '理論値 vs 実測値',
          ),
          const SizedBox(height: TofuTokens.space5),
          _ReconcileHeader(),
          for (final Denomination d in denoms)
            _ReconcileRow(
              denomination: d,
              theoretical: theoretical.countOf(d),
              actual: actualCounts[d.yen] ?? 0,
              onChanged: (v) => onChanged(d.yen, v),
            ),
          const SizedBox(height: TofuTokens.space5),
          _DiffBanner(difference: difference),
        ],
      ),
    );
  }
}

class _ReconcileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final TextStyle s = TofuTextStyles.captionBold.copyWith(
      color: TofuTokens.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space3,
        vertical: TofuTokens.space3,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: 88, child: Text('金種', style: s)),
          SizedBox(
            width: 72,
            child: Text('理論値', style: s, textAlign: TextAlign.right),
          ),
          const SizedBox(width: TofuTokens.space4),
          Expanded(child: Text('実測値', style: s)),
          SizedBox(
            width: 64,
            child: Text('差', style: s, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _ReconcileRow extends StatelessWidget {
  const _ReconcileRow({
    required this.denomination,
    required this.theoretical,
    required this.actual,
    required this.onChanged,
  });
  final Denomination denomination;
  final int theoretical;
  final int actual;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final int diff = actual - theoretical;
    final Color diffColor = diff == 0
        ? TofuTokens.textTertiary
        : diff < 0
        ? TofuTokens.dangerText
        : TofuTokens.warningText;
    final String diffText = diff == 0 ? '—' : (diff > 0 ? '+$diff' : '$diff');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TofuTokens.space3,
        vertical: TofuTokens.space3,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: TofuTokens.borderSubtle),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              '${denomination.yen}円',
              style: TofuTextStyles.bodyMdBold,
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              '$theoretical 枚',
              style: TofuTextStyles.bodyMd.copyWith(
                color: TofuTokens.textTertiary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: TofuTokens.space4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TofuNumStepper(
                value: actual,
                onChanged: onChanged,
                suffix: '枚',
                size: TofuNumStepperSize.sm,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              diffText,
              style: TofuTextStyles.bodyMdBold.copyWith(color: diffColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffBanner extends StatelessWidget {
  const _DiffBanner({required this.difference});
  final CashCloseDifference difference;

  @override
  Widget build(BuildContext context) {
    final StatusIndicatorTone tone = difference.isZero
        ? StatusIndicatorTone.success
        : (difference.isShort
              ? StatusIndicatorTone.danger
              : StatusIndicatorTone.warning);
    final String label = difference.isZero
        ? '差額なし（一致）'
        : (difference.isShort ? '不足' : '余り');
    return StatusIndicator.custom(
      label: '$label  ${TofuFormat.yen(difference.amountDiff.abs())}',
      icon: difference.isZero
          ? Icons.check_circle
          : (difference.isShort ? Icons.error : Icons.warning_amber),
      tone: tone,
    );
  }
}
