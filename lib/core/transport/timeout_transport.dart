import '../error/app_exceptions.dart';
import 'transport.dart';
import 'transport_event.dart';

/// 任意の [Transport] にタイムアウトを被せるデコレータ。
///
/// 仕様書 §7.2「規定回数を超えても確認が得られなければ送信側にエラー表示」を、
/// 「規定時間（タイムアウト）内に send が完了しなければ [TransportDeliveryException]
/// を投げる」として実装する。アプリ層の独自 ACK 機構は導入せず、
/// TCP/ATT 層の send 完了をもって「送達」と扱う。
class TimeoutTransport implements Transport {
  TimeoutTransport({
    required Transport inner,
    Duration timeout = const Duration(seconds: 5),
  })  : _inner = inner,
        _timeout = timeout;

  final Transport _inner;
  final Duration _timeout;

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Stream<TransportEvent> events() => _inner.events();

  @override
  Future<void> send(TransportEvent event) async {
    try {
      await _inner.send(event).timeout(_timeout);
    } catch (e) {
      // TimeoutException も他の通信エラーも同じ扱い: TransportDeliveryException
      throw TransportDeliveryException(
        '送信がタイムアウトもしくは失敗しました（${event.runtimeType}）: $e',
      );
    }
  }
}
