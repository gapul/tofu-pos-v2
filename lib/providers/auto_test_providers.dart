import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/export/csv_export_service.dart';
import '../features/dev_console/domain/auto_test/scenario.dart';
import '../features/dev_console/domain/auto_test/scenario_context.dart';
import '../features/dev_console/domain/auto_test/scenario_runner.dart';
import '../features/dev_console/domain/auto_test/scenarios.dart';
import 'database_providers.dart';
import 'repository_providers.dart';
import 'sync_providers.dart';
import 'usecase_providers.dart';

final Provider<ScenarioContext> scenarioContextProvider =
    Provider<ScenarioContext>(
  (Ref<ScenarioContext> ref) => ScenarioContext(
    db: ref.watch(appDatabaseProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    productRepo: ref.watch(productRepositoryProvider),
    orderRepo: ref.watch(orderRepositoryProvider),
    cashRepo: ref.watch(cashDrawerRepositoryProvider),
    kitchenRepo: ref.watch(kitchenOrderRepositoryProvider),
    callingRepo: ref.watch(callingOrderRepositoryProvider),
    poolRepo: ref.watch(ticketNumberPoolRepositoryProvider),
    logRepo: ref.watch(operationLogRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    checkout: ref.watch(checkoutUseCaseProvider),
    cancel: ref.watch(cancelOrderUseCaseProvider),
    cashClose: ref.watch(cashCloseUseCaseProvider),
    hourly: ref.watch(hourlySalesUseCaseProvider),
    dailyReset: ref.watch(dailyResetUseCaseProvider),
    csv: const CsvExportService(),
    sync: ref.watch(syncServiceProvider),
  ),
);

final Provider<List<TestScenario>> scenariosProvider =
    Provider<List<TestScenario>>((Ref<List<TestScenario>> ref) {
  return defaultScenarios();
});

final Provider<ScenarioRunner> scenarioRunnerProvider =
    Provider<ScenarioRunner>(
  (Ref<ScenarioRunner> ref) => ScenarioRunner(
    scenarios: ref.watch(scenariosProvider),
    context: ref.watch(scenarioContextProvider),
  ),
);
