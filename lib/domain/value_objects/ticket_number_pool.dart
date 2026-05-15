import 'package:meta/meta.dart';

import 'ticket_number.dart';

/// 整理券番号の払い出しプール（仕様書 §5.2 整理券番号の発番ルール）。
///
/// 不変オブジェクト。状態変更は新しいインスタンスを返す。
/// 永続化は呼び出し側（Repository）で行う。
@immutable
class TicketNumberPool {
  const TicketNumberPool({
    required this.maxNumber,
    required this.bufferSize,
    required Set<int> inUse,
    required List<int> recentlyReleased,
    Map<int, int> lastUsedAt = const <int, int>{},
    Duration cooldown = const Duration(minutes: 3),
  }) : _inUse = inUse,
       _recentlyReleased = recentlyReleased,
       _lastUsedAt = lastUsedAt,
       cooldown = cooldown;

  /// 新規プールを生成。
  factory TicketNumberPool.empty({
    int maxNumber = 99,
    int bufferSize = 10,
    Duration cooldown = const Duration(minutes: 3),
  }) {
    return TicketNumberPool(
      maxNumber: maxNumber,
      bufferSize: bufferSize,
      inUse: const <int>{},
      recentlyReleased: const <int>[],
      cooldown: cooldown,
    );
  }

  /// 番号範囲の上限（既定: 99）。
  final int maxNumber;

  /// 解放後に再利用までバッファとして保持する件数（既定: 10）。
  final int bufferSize;

  /// 使用中の番号集合。
  final Set<int> _inUse;

  /// 解放されたが再利用待ちの番号（FIFO、古い順）。
  final List<int> _recentlyReleased;

  /// 各番号が最後に release / issue された epoch ms。3 分クールタイム判定に用いる。
  final Map<int, int> _lastUsedAt;

  /// 再利用までのクールタイム（仕様: 3 分）。
  final Duration cooldown;

  Set<int> get inUseNumbers => Set<int>.unmodifiable(_inUse);
  List<int> get recentlyReleasedNumbers =>
      List<int>.unmodifiable(_recentlyReleased);
  Map<int, int> get lastUsedAtSnapshot =>
      Map<int, int>.unmodifiable(_lastUsedAt);

  /// 空き番号があるか。
  bool get hasAvailable => peekNext() != null;

  /// 次に発番する番号を取得。空きがなければ null。
  ///
  /// 「未使用かつバッファ外、かつクールタイム経過済み」の最若番を返す。
  TicketNumber? peekNext({DateTime? now}) {
    final int nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final int cooldownMs = cooldown.inMilliseconds;
    final Set<int> reserved = <int>{..._inUse, ..._recentlyReleased};
    for (int i = 1; i <= maxNumber; i++) {
      if (reserved.contains(i)) continue;
      final int? last = _lastUsedAt[i];
      if (last != null && nowMs - last < cooldownMs) continue;
      return TicketNumber(i);
    }
    return null;
  }

  /// 番号を払い出した結果のプールを返す。空きがなければ StateError。
  ({TicketNumberPool pool, TicketNumber number}) issue({DateTime? now}) {
    final TicketNumber? next = peekNext(now: now);
    if (next == null) {
      throw StateError('No available ticket number (pool exhausted)');
    }
    final int nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final Set<int> newInUse = <int>{..._inUse, next.value};
    final Map<int, int> newLastUsed = <int, int>{
      ..._lastUsedAt,
      next.value: nowMs,
    };
    return (
      pool: TicketNumberPool(
        maxNumber: maxNumber,
        bufferSize: bufferSize,
        inUse: newInUse,
        recentlyReleased: _recentlyReleased,
        lastUsedAt: newLastUsed,
        cooldown: cooldown,
      ),
      number: next,
    );
  }

  /// 番号を解放（提供済み・取消済みになったとき）。
  ///
  /// バッファに追加され、bufferSize を超えた古いものから再利用可能になる。
  /// release した瞬間に lastUsedAt を更新するので、3 分のクールタイムが起算される。
  TicketNumberPool release(TicketNumber number, {DateTime? now}) {
    if (!_inUse.contains(number.value)) {
      // すでに使用中でない番号の解放は no-op（冪等性）。
      return this;
    }
    final int nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final Set<int> newInUse = <int>{..._inUse}..remove(number.value);
    final List<int> newReleased = <int>[..._recentlyReleased, number.value];
    final Map<int, int> newLastUsed = <int, int>{
      ..._lastUsedAt,
      number.value: nowMs,
    };

    // バッファサイズを超えた古いものは捨てる（再利用可能になる）。
    while (newReleased.length > bufferSize) {
      newReleased.removeAt(0);
    }
    return TicketNumberPool(
      maxNumber: maxNumber,
      bufferSize: bufferSize,
      inUse: newInUse,
      recentlyReleased: newReleased,
      lastUsedAt: newLastUsed,
      cooldown: cooldown,
    );
  }

  /// 営業日切替などでプールを完全リセット。
  TicketNumberPool reset() {
    return TicketNumberPool.empty(
      maxNumber: maxNumber,
      bufferSize: bufferSize,
      cooldown: cooldown,
    );
  }

  @override
  String toString() =>
      'TicketNumberPool(max: $maxNumber, inUse: ${_inUse.length}, buffer: ${_recentlyReleased.length})';
}
