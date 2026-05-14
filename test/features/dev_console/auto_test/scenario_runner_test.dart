import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/core/connectivity/connectivity_monitor.dart';
import 'package:tofu_pos/core/connectivity/connectivity_status.dart';
import 'package:tofu_pos/core/export/csv_export_service.dart';
import 'package:tofu_pos/core/sync/cloud_sync_client.dart';
import 'package:tofu_pos/core/sync/sync_service.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_calling_order_repository.dart';
import 'package:tofu_pos/data/repositories/drift_cash_drawer_repository.dart';
import 'package:tofu_pos/data/repositories/drift_kitchen_order_repository.dart';
import 'package:tofu_pos/data/repositories/drift_operation_log_repository.dart';
import 'package:tofu_pos/data/repositories/drift_order_repository.dart';
import 'package:tofu_pos/data/repositories/drift_product_repository.dart';
import 'package:tofu_pos/data/repositories/drift_unit_of_work.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_daily_reset_repository.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_settings_repository.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_ticket_pool_repository.dart';
import 'package:tofu_pos/domain/usecases/cancel_order_usecase.dart';
import 'package:tofu_pos/domain/usecases/cash_close_usecase.dart';
import 'package:tofu_pos/domain/usecases/checkout_usecase.dart';
import 'package:tofu_pos/domain/usecases/daily_reset_usecase.dart';
import 'package:tofu_pos/domain/usecases/hourly_sales_usecase.dart';
import 'package:tofu_pos/features/dev_console/domain/auto_test/scenario.dart';
import 'package:tofu_pos/features/dev_console/domain/auto_test/scenario_context.dart';
import 'package:tofu_pos/features/dev_console/domain/auto_test/scenario_runner.dart';
import 'package:tofu_pos/features/dev_console/domain/auto_test/scenarios.dart';

/// 本物の drift / SharedPreferences で ScenarioContext を組み立てる。
Future<ScenarioContext> _buildContext() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());

  final productRepo = DriftProductRepository(db);
  final orderRepo = DriftOrderRepository(db);
  final cashRepo = DriftCashDrawerRepository(db);
  final kitchenRepo = DriftKitchenOrderRepository(db);
  final callingRepo = DriftCallingOrderRepository(db);
  final logRepo = DriftOperationLogRepository(db);
  final settings = SharedPrefsSettingsRepository(prefs);
  final poolRepo = SharedPrefsTicketPoolRepository(prefs);
  final dailyRepo = SharedPrefsDailyResetRepository(prefs);
  final uow = DriftUnitOfWork(db);

  final checkout = CheckoutUseCase(
    unitOfWork: uow,
    orderRepository: orderRepo,
    productRepository: productRepo,
    cashDrawerRepository: cashRepo,
    ticketPoolRepository: poolRepo,
  );
  final cancel = CancelOrderUseCase(
    unitOfWork: uow,
    orderRepository: orderRepo,
    productRepository: productRepo,
    cashDrawerRepository: cashRepo,
    ticketPoolRepository: poolRepo,
    operationLogRepository: logRepo,
  );

  return ScenarioContext(
    db: db,
    prefs: prefs,
    productRepo: productRepo,
    orderRepo: orderRepo,
    cashRepo: cashRepo,
    kitchenRepo: kitchenRepo,
    callingRepo: callingRepo,
    poolRepo: poolRepo,
    logRepo: logRepo,
    settings: settings,
    checkout: checkout,
    cancel: cancel,
    cashClose: CashCloseUseCase(
      orderRepository: orderRepo,
      cashDrawerRepository: cashRepo,
    ),
    hourly: HourlySalesUseCase(orderRepository: orderRepo),
    dailyReset: DailyResetUseCase(
      dailyResetRepository: dailyRepo,
      ticketPoolRepository: poolRepo,
    ),
    csv: const CsvExportService(),
    sync: SyncService(
      orderRepository: orderRepo,
      settingsRepository: settings,
      connectivityMonitor: _AlwaysOfflineMonitor(),
      client: NoopCloudSyncClient(),
    ),
  );
}

class _AlwaysOfflineMonitor implements ConnectivityMonitor {
  @override
  ConnectivityStatus get current => ConnectivityStatus.offline;

  @override
  Stream<ConnectivityStatus> watch() async* {
    yield ConnectivityStatus.offline;
  }
}

void main() {
  test('runs all default scenarios; all pass', () async {
    final ScenarioContext ctx = await _buildContext();
    final ScenarioRunner runner = ScenarioRunner(
      scenarios: defaultScenarios(),
      context: ctx,
    );
    final List<ScenarioReport> reports = await runner.runAll().toList();

    expect(reports, hasLength(defaultScenarios().length));
    // skipped は通信経路シナリオで Transport 未注入のため発生する。
    // 「passed でも skipped でもない」結果のみを失敗扱いにする。
    final List<ScenarioReport> failures = reports
        .where((r) => !r.result.passed && !r.result.skipped)
        .toList();
    expect(
      failures,
      isEmpty,
      reason:
          'failed: ${failures.map((r) => "${r.scenario.id}: ${r.result.message}").join(", ")}',
    );

    await ctx.db.close();
  });

  test('runOne resets state before running (idempotent)', () async {
    final ScenarioContext ctx = await _buildContext();
    final ScenarioRunner runner = ScenarioRunner(
      scenarios: defaultScenarios(),
      context: ctx,
    );
    final TestScenario scenario = defaultScenarios().first;
    final ScenarioReport r1 = await runner.runOne(scenario);
    final ScenarioReport r2 = await runner.runOne(scenario);
    expect(r1.result.passed, isTrue);
    expect(r2.result.passed, isTrue);
    await ctx.db.close();
  });

  test('uncaught exception is captured as fail result', () async {
    final ScenarioContext ctx = await _buildContext();
    final TestScenario broken = TestScenario(
      id: 'broken',
      name: 'broken',
      description: 'always throws',
      run: (ctx) async => throw StateError('intentional'),
    );
    final ScenarioRunner runner = ScenarioRunner(
      scenarios: <TestScenario>[broken],
      context: ctx,
    );
    final List<ScenarioReport> reports = await runner.runAll().toList();
    expect(reports.single.result.passed, isFalse);
    expect(reports.single.result.message, contains('uncaught'));
    await ctx.db.close();
  });
}
