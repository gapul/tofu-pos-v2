import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  Future<TicketNumberPool> load() async {
    final String? raw = _prefs.getString(_kPool);
    if (raw == null) {
      return TicketNumberPool.empty(
        maxNumber: _defaultMax,
        bufferSize: _defaultBuffer,
      );
    }
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return TicketNumberPool(
      maxNumber: json['maxNumber'] as int,
      bufferSize: json['bufferSize'] as int,
      inUse: (json['inUse'] as List<dynamic>).cast<int>().toSet(),
      recentlyReleased: (json['recentlyReleased'] as List<dynamic>)
          .cast<int>()
          .toList(),
    );
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
      final ({TicketNumberPool pool, TicketNumber number}) issued = pool
          .issue();
      await save(issued.pool);
      return issued.number;
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
}
