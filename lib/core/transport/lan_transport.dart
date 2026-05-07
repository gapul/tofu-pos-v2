import '../../data/datasources/lan/lan_client.dart';
import '../../data/datasources/lan/lan_server.dart';
import 'transport.dart';
import 'transport_event.dart';

/// ローカルLAN経由の Transport（仕様書 §7.1）。
///
/// 役割により内部実装を切り替える:
///  - レジ: [LanClient]（mDNS ディスカバリ + WebSocket クライアント、複数 peer）
///  - キッチン/呼び出し: [LanServer]（WebSocket サーバ + mDNS broadcast）
class LanTransport implements Transport {
  LanTransport.client(LanClient client) : _impl = _ClientImpl(client);
  LanTransport.server(LanServer server) : _impl = _ServerImpl(server);

  final _LanImpl _impl;

  @override
  Future<void> connect() => _impl.connect();

  @override
  Future<void> disconnect() => _impl.disconnect();

  @override
  Stream<TransportEvent> events() => _impl.events();

  @override
  Future<void> send(TransportEvent event) => _impl.send(event);
}

abstract class _LanImpl {
  Future<void> connect();
  Future<void> disconnect();
  Stream<TransportEvent> events();
  Future<void> send(TransportEvent event);
}

class _ClientImpl implements _LanImpl {
  _ClientImpl(this._client);
  final LanClient _client;

  @override
  Future<void> connect() => _client.start();

  @override
  Future<void> disconnect() => _client.stop();

  @override
  Stream<TransportEvent> events() => _client.events();

  @override
  Future<void> send(TransportEvent event) => _client.broadcast(event);
}

class _ServerImpl implements _LanImpl {
  _ServerImpl(this._server);
  final LanServer _server;

  @override
  Future<void> connect() => _server.start();

  @override
  Future<void> disconnect() => _server.stop();

  @override
  Stream<TransportEvent> events() => _server.events();

  @override
  Future<void> send(TransportEvent event) => _server.broadcast(event);
}
