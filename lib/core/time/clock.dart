import 'package:flutter_riverpod/flutter_riverpod.dart';

/// アプリ全体で参照する「現在時刻」の単一の入口。
///
/// JST 固定。UTC が必要な場合は明示的に [nowUtc] を呼ぶ。
/// テストでは [FakeClock] を `clockProvider` に override して固定する。
abstract class Clock {
  const Clock();

  /// 現在時刻（JST, +09:00）。
  ///
  /// `DateTime` は内部的にローカル/UTC のどちらかしか持てないが、本実装は
  /// 「タイムゾーン情報抜きの JST 壁時計」を返す。比較や算術は同じ Clock
  /// から取得した値どうしで行うこと。
  DateTime now();

  /// 当日の 00:00（JST）を表す DateTime。
  ///
  /// 営業日切替・日次リセット判定などに使う。
  DateTime todayJst();

  /// 純粋に UTC が必要な場合（外部 API への送信時刻など）。
  DateTime nowUtc();
}

/// 既定実装: 端末時計から JST を計算。
class SystemClock extends Clock {
  const SystemClock();

  static const Duration _jstOffset = Duration(hours: 9);

  @override
  DateTime now() {
    final DateTime utc = DateTime.now().toUtc();
    final DateTime jst = utc.add(_jstOffset);
    // タイムゾーン情報を持たない壁時計として返す。
    return DateTime(
      jst.year,
      jst.month,
      jst.day,
      jst.hour,
      jst.minute,
      jst.second,
      jst.millisecond,
      jst.microsecond,
    );
  }

  @override
  DateTime todayJst() {
    final DateTime n = now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// テスト用: 固定時刻を返す。
class FakeClock extends Clock {
  FakeClock(this._now, {DateTime? utc}) : _utc = utc ?? _now.toUtc();

  DateTime _now;
  DateTime _utc;

  /// 現在時刻を進める。
  void advance(Duration delta) {
    _now = _now.add(delta);
    _utc = _utc.add(delta);
  }

  /// 現在時刻を直接置き換える（JST 壁時計 + UTC を同期更新）。
  void setNow(DateTime jstWallClock, {DateTime? utc}) {
    _now = jstWallClock;
    _utc = utc ?? jstWallClock.toUtc();
  }

  @override
  DateTime now() => _now;

  @override
  DateTime todayJst() => DateTime(_now.year, _now.month, _now.day);

  @override
  DateTime nowUtc() => _utc;
}

/// Riverpod から参照する Clock。テストで override する。
final Provider<Clock> clockProvider = Provider<Clock>((ref) {
  return const SystemClock();
});
