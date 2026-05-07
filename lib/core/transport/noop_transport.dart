import 'dart:async';

import 'transport.dart';
import 'transport_event.dart';

/// 何もしない Transport（テスト・初期開発時のスタブ）。
///
/// 送信は記録のみ、受信は空の Stream。
class NoopTransport implements Transport {
  final List<TransportEvent> sent = <TransportEvent>[];
  final StreamController<TransportEvent> _controller =
      StreamController<TransportEvent>.broadcast();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    await _controller.close();
  }

  @override
  Stream<TransportEvent> events() => _controller.stream;

  @override
  Future<void> send(TransportEvent event) async {
    sent.add(event);
  }

  /// テスト用: 受信イベントを擬似発生させる。
  void emit(TransportEvent event) => _controller.add(event);
}
