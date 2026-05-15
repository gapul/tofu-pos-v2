import 'dart:convert';

import '../../core/logging/app_logger.dart';
import '../entities/operation_log.dart';
import '../repositories/daily_reset_repository.dart';
import '../repositories/operation_log_repository.dart';
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
    OperationLogRepository? operationLogRepository,
    DateTime Function() now = DateTime.now,
  }) : _dailyResetRepo = dailyResetRepository,
       _poolRepo = ticketPoolRepository,
       _logRepo = operationLogRepository,
       _now = now;

  final DailyResetRepository _dailyResetRepo;
  final TicketNumberPoolRepository _poolRepo;
  final OperationLogRepository? _logRepo;
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

    // 直列化済み API を使う。load + save の直書きは並行する allocate と
    // 干渉して整理券番号の不整合を起こす温床になる。
    await _poolRepo.reset();
    await _dailyResetRepo.setLastResetDate(today);
    if (_logRepo != null) {
      await _logRepo.record(
        kind: OperationKind.dailyReset,
        targetId: today.toIso8601String(),
        detailJson: jsonEncode(<String, Object?>{
          'today': today.toIso8601String(),
          'last_reset': last?.toIso8601String(),
        }),
        at: _now(),
      );
    }
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
