import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/export/csv_export_service.dart';
import '../core/transport/transport.dart';
import '../domain/enums/transport_mode.dart';
import '../domain/value_objects/shop_id.dart';
import '../features/dev_console/domain/auto_test/scenario.dart';
import '../features/dev_console/domain/auto_test/scenario_context.dart';
import '../features/dev_console/domain/auto_test/scenario_runner.dart';
import '../features/dev_console/domain/auto_test/scenarios.dart';
import 'database_providers.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';
import 'sync_providers.dart';
import 'usecase_providers.dart';

/// 自動テストのコンテキスト。
///
/// 通信経路系シナリオが利用する Transport / TransportMode / Supabase /
/// shopId を **可能なら**詰める。未取得・未設定なら null のまま返す。
/// シナリオ側で null チェックして `ScenarioResult.skip` で逃げる。
final FutureProvider<ScenarioContext> scenarioContextProvider =
    FutureProvider<ScenarioContext>((ref) async {
      // Transport / TransportMode / shopId は失敗しても scenarioContext 自体は
      // 返したいので、個別に try で握り潰す（通信系シナリオが skip するだけ）。
      Transport? transport;
      try {
        transport = await ref.watch(transportProvider.future);
      } catch (_) {
        transport = null;
      }

      TransportMode? mode;
      try {
        mode = await ref.watch(transportModeProvider.future);
      } catch (_) {
        mode = null;
      }

      String? shopIdString;
      try {
        final ShopId? id = await ref
            .watch(settingsRepositoryProvider)
            .getShopId();
        shopIdString = id?.value;
      } catch (_) {
        shopIdString = null;
      }

      SupabaseClient? supabaseClient;
      if (Env.hasSupabaseCredentials) {
        try {
          supabaseClient = Supabase.instance.client;
        } catch (_) {
          supabaseClient = null;
        }
      }

      return ScenarioContext(
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
        transport: transport,
        transportMode: mode,
        supabaseClient: supabaseClient,
        shopId: shopIdString,
        hasSupabaseCredentials: Env.hasSupabaseCredentials,
      );
    });

final Provider<List<TestScenario>> scenariosProvider =
    Provider<List<TestScenario>>((ref) {
      return defaultScenarios();
    });

final FutureProvider<ScenarioRunner> scenarioRunnerProvider =
    FutureProvider<ScenarioRunner>((ref) async {
      final ScenarioContext context = await ref.watch(
        scenarioContextProvider.future,
      );
      return ScenarioRunner(
        scenarios: ref.watch(scenariosProvider),
        context: context,
      );
    });
