import '../../core/logging/app_logger.dart';
import '../repositories/daily_reset_repository.dart';
import '../repositories/ticket_number_pool_repository.dart';

/// 営業日が変わった時に実行する日次リセット（仕様書 §5.2 / §6.4）。
///
/// 現在の整理券プール状態は **使用済番号のバッファ含めてすべてリセット**される。
/// 商品マスタ・金種在庫・機能フラグ等の設定情報は影響を受けない。
///
/// 呼び出しタイミング: アプリ起動時（main.dart 直後の早い段階）。
class DailyResetUseCase {
  DailyResetUseCase({
    required DailyResetRepository dailyResetRepository,
    required TicketNumberPoolRepository ticketPoolRepository,
    DateTime Function() now = DateTime.now,
  })  : _dailyResetRepo = dailyResetRepository,
        _poolRepo = ticketPoolRepository,
        _now = now;

  final DailyResetRepository _dailyResetRepo;
  final TicketNumberPoolRepository _poolRepo;
  final DateTime Function() _now;

  /// 必要なら整理券プールをリセットする。
  ///
  /// 戻り値: リセットが実行された場合 true、不要だった場合 false。
  Future<bool> runIfNeeded() async {
    final DateTime today = _today();
    final DateTime? last = await _dailyResetRepo.getLastResetDate();

    if (last != null && _isSameDay(last, today)) {
      return false;
    }

    final pool = await _poolRepo.load();
    await _poolRepo.save(pool.reset());
    await _dailyResetRepo.setLastResetDate(today);
    AppLogger.i('Daily reset performed for $today (was: $last)');
    return true;
  }

  DateTime _today() {
    final DateTime n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
