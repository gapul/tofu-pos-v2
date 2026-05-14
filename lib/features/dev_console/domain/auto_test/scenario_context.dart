import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/export/csv_export_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/transport/transport.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../domain/enums/transport_mode.dart';
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
///
/// 通信経路系シナリオ（transport.*）のために
/// [transport] / [transportMode] / [supabaseClient] / [shopId] /
/// [hasSupabaseCredentials] を **任意フィールド**として持つ。
/// 既存シナリオは触れないし、テストでも未指定でよい。
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
    this.transport,
    this.transportMode,
    this.supabaseClient,
    this.shopId,
    this.hasSupabaseCredentials = false,
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

  // === 通信経路シナリオ用（optional） ===

  /// 現在アクティブな Transport。null の場合は通信系シナリオは skip。
  final Transport? transport;

  /// 現在の TransportMode。null の場合は skip。
  final TransportMode? transportMode;

  /// online シナリオでの DB クエリに使う Supabase クライアント。
  /// テスト時は null で skip。
  final SupabaseClient? supabaseClient;

  /// shop_id 文字列。null の場合は通信系シナリオは skip。
  final String? shopId;

  /// Env に Supabase 認証情報が揃っているか（online シナリオの前提）。
  final bool hasSupabaseCredentials;
}
