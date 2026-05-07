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
  }) : _inUse = inUse,
       _recentlyReleased = recentlyReleased;

  /// 新規プールを生成。
  factory TicketNumberPool.empty({int maxNumber = 99, int bufferSize = 10}) {
    return TicketNumberPool(
      maxNumber: maxNumber,
      bufferSize: bufferSize,
      inUse: const <int>{},
      recentlyReleased: const <int>[],
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

  Set<int> get inUseNumbers => Set<int>.unmodifiable(_inUse);
  List<int> get recentlyReleasedNumbers =>
      List<int>.unmodifiable(_recentlyReleased);

  /// 空き番号があるか。
  bool get hasAvailable {
    if (_inUse.length + _bufferActive < maxNumber) {
      return true;
    }
    return false;
  }

  int get _bufferActive {
    // バッファに入っている件数のうち、まだ再利用不可なもの。
    return _recentlyReleased.length;
  }

  /// 次に発番する番号を取得。空きがなければ null。
  ///
  /// 「未使用かつバッファ外の最若番」を返す。
  TicketNumber? peekNext() {
    final Set<int> reserved = <int>{..._inUse, ..._recentlyReleased};
    for (int i = 1; i <= maxNumber; i++) {
      if (!reserved.contains(i)) {
        return TicketNumber(i);
      }
    }
    return null;
  }

  /// 番号を払い出した結果のプールを返す。空きがなければ StateError。
  ({TicketNumberPool pool, TicketNumber number}) issue() {
    final TicketNumber? next = peekNext();
    if (next == null) {
      throw StateError('No available ticket number (pool exhausted)');
    }
    final Set<int> newInUse = <int>{..._inUse, next.value};
    return (
      pool: TicketNumberPool(
        maxNumber: maxNumber,
        bufferSize: bufferSize,
        inUse: newInUse,
        recentlyReleased: _recentlyReleased,
      ),
      number: next,
    );
  }

  /// 番号を解放（提供済み・取消済みになったとき）。
  ///
  /// バッファに追加され、bufferSize を超えた古いものから再利用可能になる。
  TicketNumberPool release(TicketNumber number) {
    if (!_inUse.contains(number.value)) {
      // すでに使用中でない番号の解放は no-op（冪等性）。
      return this;
    }
    final Set<int> newInUse = <int>{..._inUse}..remove(number.value);
    final List<int> newReleased = <int>[..._recentlyReleased, number.value];

    // バッファサイズを超えた古いものは捨てる（再利用可能になる）。
    while (newReleased.length > bufferSize) {
      newReleased.removeAt(0);
    }
    return TicketNumberPool(
      maxNumber: maxNumber,
      bufferSize: bufferSize,
      inUse: newInUse,
      recentlyReleased: newReleased,
    );
  }

  /// 営業日切替などでプールを完全リセット。
  TicketNumberPool reset() {
    return TicketNumberPool.empty(maxNumber: maxNumber, bufferSize: bufferSize);
  }

  @override
  String toString() =>
      'TicketNumberPool(max: $maxNumber, inUse: ${_inUse.length}, buffer: ${_recentlyReleased.length})';
}
