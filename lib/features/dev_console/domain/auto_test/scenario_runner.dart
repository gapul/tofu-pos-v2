import 'dart:async';

import '../../../../core/logging/app_logger.dart';
import 'scenario.dart';
import 'scenario_context.dart';

/// シナリオ実行報告（1件分）。
class ScenarioReport {
  const ScenarioReport(this.scenario, this.result);
  final TestScenario scenario;
  final ScenarioResult result;
}

/// 全シナリオを順番に走らせるランナー。
///
/// 各シナリオの前に状態をリセット（DB全削除 + SharedPreferences の関連キー削除）
/// するため、シナリオは独立に書ける。
class ScenarioRunner {
  ScenarioRunner({required this.scenarios, required this.context});

  final List<TestScenario> scenarios;
  final ScenarioContext context;

  /// 全シナリオを順次実行し、結果を Stream で随時 emit する。
  Stream<ScenarioReport> runAll() async* {
    for (final TestScenario s in scenarios) {
      yield await _runOne(s);
    }
  }

  /// 単一シナリオの実行（外部からも呼べる）。
  Future<ScenarioReport> runOne(TestScenario s) => _runOne(s);

  Future<ScenarioReport> _runOne(TestScenario s) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      await _resetState();
      final ScenarioResult result = await s.run(context);
      sw.stop();
      final String status = result.skipped
          ? 'SKIP'
          : (result.passed ? 'PASS' : 'FAIL');
      AppLogger.i(
        'Scenario "${s.name}": $status '
        '— ${result.message} (${sw.elapsed.inMilliseconds}ms)',
      );
      return ScenarioReport(s, result.withDuration(sw.elapsed));
    } catch (e, st) {
      sw.stop();
      AppLogger.e('Scenario "${s.name}" threw: $e', error: e, stackTrace: st);
      return ScenarioReport(
        s,
        ScenarioResult.fail('uncaught: $e').withDuration(sw.elapsed),
      );
    }
  }

  /// 全テーブルを空にし、関連 SharedPreferences キーを削除。
  Future<void> _resetState() async {
    final db = context.db;
    await db.transaction(() async {
      // 順序: 子→親（FK 制約に沿って）
      await db.delete(db.orderItems).go();
      await db.delete(db.orders).go();
      await db.delete(db.products).go();
      await db.delete(db.cashDrawerCounts).go();
      await db.delete(db.kitchenOrders).go();
      await db.delete(db.callingOrders).go();
      await db.delete(db.operationLogs).go();
    });
    final prefs = context.prefs;
    await prefs.remove('ticketPool');
    await prefs.remove('lastResetDate');
  }
}
