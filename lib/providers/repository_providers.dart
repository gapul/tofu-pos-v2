import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/drift_calling_order_repository.dart';
import '../data/repositories/drift_cash_drawer_repository.dart';
import '../data/repositories/drift_kitchen_order_repository.dart';
import '../data/repositories/drift_operation_log_repository.dart';
import '../data/repositories/drift_order_repository.dart';
import '../data/repositories/drift_product_repository.dart';
import '../data/repositories/drift_unit_of_work.dart';
import '../data/repositories/shared_prefs_daily_reset_repository.dart';
import '../data/repositories/shared_prefs_settings_repository.dart';
import '../data/repositories/shared_prefs_ticket_pool_repository.dart';
import '../domain/repositories/calling_order_repository.dart';
import '../domain/repositories/cash_drawer_repository.dart';
import '../domain/repositories/daily_reset_repository.dart';
import '../domain/repositories/kitchen_order_repository.dart';
import '../domain/repositories/operation_log_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/product_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/ticket_number_pool_repository.dart';
import '../domain/repositories/unit_of_work.dart';
import 'database_providers.dart';

final Provider<UnitOfWork> unitOfWorkProvider = Provider<UnitOfWork>(
  (Ref<UnitOfWork> ref) => DriftUnitOfWork(ref.watch(appDatabaseProvider)),
);

final Provider<ProductRepository> productRepositoryProvider =
    Provider<ProductRepository>(
      (Ref<ProductRepository> ref) =>
          DriftProductRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<OrderRepository> orderRepositoryProvider =
    Provider<OrderRepository>(
      (Ref<OrderRepository> ref) =>
          DriftOrderRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<CashDrawerRepository> cashDrawerRepositoryProvider =
    Provider<CashDrawerRepository>(
      (Ref<CashDrawerRepository> ref) =>
          DriftCashDrawerRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref<SettingsRepository> ref) =>
          SharedPrefsSettingsRepository(ref.watch(sharedPreferencesProvider)),
    );

final Provider<TicketNumberPoolRepository> ticketNumberPoolRepositoryProvider =
    Provider<TicketNumberPoolRepository>(
      (Ref<TicketNumberPoolRepository> ref) =>
          SharedPrefsTicketPoolRepository(ref.watch(sharedPreferencesProvider)),
    );

final Provider<OperationLogRepository> operationLogRepositoryProvider =
    Provider<OperationLogRepository>(
      (Ref<OperationLogRepository> ref) =>
          DriftOperationLogRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<DailyResetRepository> dailyResetRepositoryProvider =
    Provider<DailyResetRepository>(
      (Ref<DailyResetRepository> ref) =>
          SharedPrefsDailyResetRepository(ref.watch(sharedPreferencesProvider)),
    );

final Provider<KitchenOrderRepository> kitchenOrderRepositoryProvider =
    Provider<KitchenOrderRepository>(
      (Ref<KitchenOrderRepository> ref) =>
          DriftKitchenOrderRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<CallingOrderRepository> callingOrderRepositoryProvider =
    Provider<CallingOrderRepository>(
      (Ref<CallingOrderRepository> ref) =>
          DriftCallingOrderRepository(ref.watch(appDatabaseProvider)),
    );
