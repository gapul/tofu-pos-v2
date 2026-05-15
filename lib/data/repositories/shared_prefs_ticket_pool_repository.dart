import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/error/app_exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../core/telemetry/telemetry.dart';
import '../../domain/repositories/ticket_number_pool_repository.dart';
import '../../domain/value_objects/ticket_number.dart';
import '../../domain/value_objects/ticket_number_pool.dart';

/// SharedPreferences ベースの TicketNumberPoolRepository。
///
/// 状態は単一の JSON 文字列として保存:
/// {
///   "maxNumber": 99,
///   "bufferSize": 10,
///   "inUse": [1, 3, 7],
///   "recentlyReleased": [2, 4]
/// }
///
/// 並行性: `allocate` / `release` は内部の Future チェーンでシリアライズされ、
/// `load -> issue/release -> save` がアトミックに実行される。
class SharedPrefsTicketPoolRepository implements TicketNumberPoolRepository {
  SharedPrefsTicketPoolRepository(
    this._prefs, {
    int defaultMaxNumber = 99,
    int defaultBufferSize = 10,
  }) : _defaultMax = defaultMaxNumber,
       _defaultBuffer = defaultBufferSize;

  final SharedPreferences _prefs;
  final int _defaultMax;
  final int _defaultBuffer;

  /// 直列化用のテール。allocate / release は前回の完了を待ってから走る。
  Future<void> _lock = Future<void>.value();

  static const String _kPool = 'ticketPool';

  /// 補償 release 失敗時の未処理キュー。`int` の配列を JSON 文字列で保存。
  static const String _kPendingReleases = 'ticketPool.pendingReleases';

  @override
  Future<TicketNumberPool> load() async {
    final String? raw = _prefs.getString(_kPool);
    if (raw == null) {
      return TicketNumberPool.empty(
        maxNumber: _defaultMax,
        bufferSize: _defaultBuffer,
      );
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      return TicketNumberPool(
        maxNumber: json['maxNumber'] as int,
        bufferSize: json['bufferSize'] as int,
        inUse: (json['inUse'] as List<dynamic>).cast<int>().toSet(),
        recentlyReleased: (json['recentlyReleased'] as List<dynamic>)
            .cast<int>()
            .toList(),
      );
    } catch (e, st) {
      // 永続層が壊れている。空に倒すと整理券番号の再利用が起きるため
      // ここでは絶対に黙って空プールを返さない。loud に throw する。
      // 致命的なので構造化イベントを error レベルで残す（ダッシュボード可視化）。
      AppLogger.event(
        'ticket_pool',
        'load.corrupted',
        fields: <String, Object?>{'error': e.toString()},
        level: AppLogLevel.error,
      );
      AppLogger.e(
        'TicketPool persisted state is corrupted; refusing to reset',
        error: e,
        stackTrace: st,
      );
      Telemetry.instance.error(
        'ticket_pool.load.corrupted',
        message: 'persisted JSON is unparseable',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> save(TicketNumberPool pool) async {
    final Map<String, Object> json = <String, Object>{
      'maxNumber': pool.maxNumber,
      'bufferSize': pool.bufferSize,
      'inUse': pool.inUseNumbers.toList()..sort(),
      'recentlyReleased': pool.recentlyReleasedNumbers,
    };
    await _prefs.setString(_kPool, jsonEncode(json));
  }

  /// 内部ロック: `body` を直列化して実行する。
  Future<T> _synchronized<T>(Future<T> Function() body) {
    final Completer<T> result = Completer<T>();
    final Future<void> previous = _lock;
    _lock = previous.then((_) async {
      try {
        result.complete(await body());
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  @override
  Future<TicketNumber> allocate() {
    return _synchronized<TicketNumber>(() async {
      final TicketNumberPool pool = await load();
      if (!pool.hasAvailable) {
        // 枯渇は業務上ありうるエラーなので、ドメイン例外に詰め替える。
        // `issue()` の StateError は内部実装の都合なので外には出さない。
        throw const TicketPoolExhaustedException();
      }
      try {
        final ({TicketNumberPool pool, TicketNumber number}) issued = pool
            .issue();
        await save(issued.pool);
        return issued.number;
        // `hasAvailable` を通過した直後の枯渇（バッファ計算の境界ケース）でも
        // 同じドメイン例外に揃える。StateError は通常握らないが、ここは
        // `issue()` の契約由来なので明示的に変換する。
        // ignore: avoid_catching_errors
      } on StateError {
        throw const TicketPoolExhaustedException();
      }
    });
  }

  @override
  Future<void> release(TicketNumber number) {
    return _synchronized<void>(() async {
      final TicketNumberPool pool = await load();
      final TicketNumberPool next = pool.release(number);
      await save(next);
    });
  }

  @override
  Future<void> reset() {
    return _synchronized<void>(() async {
      final TicketNumberPool pool = await load();
      await save(pool.reset());
    });
  }

  @override
  Future<void> enqueuePendingRelease(TicketNumber number) {
    return _synchronized<void>(() async {
      final List<int> current = _readPendingRaw();
      if (current.contains(number.value)) return;
      current.add(number.value);
      await _writePendingRaw(current);
      AppLogger.event(
        'ticket_pool',
        'pending_release.enqueued',
        fields: <String, Object?>{
          'ticket_number': number.value,
          'queue_size': current.length,
        },
      );
      Telemetry.instance.warn(
        'ticket_pool.pending_release.enqueued',
        attrs: <String, Object?>{
          'ticket_number': number.value,
          'queue_size': current.length,
        },
      );
    });
  }

  @override
  Future<List<TicketNumber>> pendingReleases() async {
    final List<int> current = _readPendingRaw();
    return <TicketNumber>[
      for (final int v in current) TicketNumber(v),
    ];
  }

  @override
  Future<int> flushPendingReleases() async {
    final List<int> snapshot = _readPendingRaw();
    if (snapshot.isEmpty) return 0;
    int processed = 0;
    final List<int> remaining = <int>[];
    for (final int value in snapshot) {
      try {
        await release(TicketNumber(value));
        processed++;
      } catch (e, st) {
        // 個別 release の失敗は次回 flush に持ち越し。残量はログ + telemetry で可視化。
        remaining.add(value);
        AppLogger.w(
          'TicketPool: pending release flush failed for #$value',
          error: e,
          stackTrace: st,
        );
        Telemetry.instance.error(
          'ticket_pool.pending_release.flush_failed',
          error: e,
          stackTrace: st,
          attrs: <String, Object?>{'ticket_number': value},
        );
      }
    }
    // 残りを永続化。空なら key を削除して clean に。
    await _synchronized<void>(() async {
      // flush 中に enqueue されたぶんを失わないように merge する。
      final List<int> latest = _readPendingRaw();
      final Set<int> merged = <int>{...remaining};
      for (final v in latest) {
        if (!snapshot.contains(v)) merged.add(v);
      }
      await _writePendingRaw(merged.toList()..sort());
    });
    if (processed > 0) {
      Telemetry.instance.event(
        'ticket_pool.pending_release.flushed',
        attrs: <String, Object?>{
          'processed': processed,
          'remaining': remaining.length,
        },
      );
    }
    return processed;
  }

  List<int> _readPendingRaw() {
    final String? raw = _prefs.getString(_kPendingReleases);
    if (raw == null || raw.isEmpty) return <int>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<num>().map((n) => n.toInt()).toList();
      }
    } catch (e, st) {
      // 壊れていたら捨てる。pending は本質的に「念のため積む」キューなので
      // 失った場合の影響は「番号がバッファに戻らない」だけ（日次リセットで清掃される）。
      AppLogger.w(
        'TicketPool: pending releases JSON corrupted; dropping',
        error: e,
        stackTrace: st,
      );
      Telemetry.instance.warn(
        'ticket_pool.pending_release.corrupted',
        attrs: <String, Object?>{'error': e.toString()},
      );
    }
    return <int>[];
  }

  Future<void> _writePendingRaw(List<int> values) async {
    if (values.isEmpty) {
      await _prefs.remove(_kPendingReleases);
      return;
    }
    await _prefs.setString(_kPendingReleases, jsonEncode(values));
  }
}
