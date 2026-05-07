import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/export/csv_export_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../domain/repositories/calling_order_repository.dart';
import '../../../../domain/repositories/cash_drawer_repository.dart';
import '../../../../domain/repositories/kitchen_order_repository.dart';
import '../../../../domain/repositories/operation_log_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../../../../domain/repositories/product_repository.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../../domain/repositories/ticket_number_pool_repository.dart';
import '../../../../domain/usecases/cancel_order_usecase.dart';
import '../../../../domain/usecases/cash_close_usecase.dart';
import '../../../../domain/usecases/checkout_usecase.dart';
import '../../../../domain/usecases/daily_reset_usecase.dart';
import '../../../../domain/usecases/hourly_sales_usecase.dart';

/// シナリオが利用する依存関係をまとめた DTO。
///
/// テスト時はこれをモックで埋めて、シナリオ関数を直接呼べるようにする。
class ScenarioContext {
  const ScenarioContext({
    required this.db,
    required this.prefs,
    required this.productRepo,
    required this.orderRepo,
    required this.cashRepo,
    required this.kitchenRepo,
    required this.callingRepo,
    required this.poolRepo,
    required this.logRepo,
    required this.settings,
    required this.checkout,
    required this.cancel,
    required this.cashClose,
    required this.hourly,
    required this.dailyReset,
    required this.csv,
    required this.sync,
  });

  final AppDatabase db;
  final SharedPreferences prefs;

  final ProductRepository productRepo;
  final OrderRepository orderRepo;
  final CashDrawerRepository cashRepo;
  final KitchenOrderRepository kitchenRepo;
  final CallingOrderRepository callingRepo;
  final TicketNumberPoolRepository poolRepo;
  final OperationLogRepository logRepo;
  final SettingsRepository settings;

  final CheckoutUseCase checkout;
  final CancelOrderUseCase cancel;
  final CashCloseUseCase cashClose;
  final HourlySalesUseCase hourly;
  final DailyResetUseCase dailyReset;

  final CsvExportService csv;
  final SyncService sync;
}
