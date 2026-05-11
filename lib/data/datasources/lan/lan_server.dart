import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport_event.dart';
import 'lan_protocol.dart';

/// キッチン・呼び出し端末側で動かす WebSocket サーバ + mDNS サービス公開。
///
/// 仕様書 §7.1 ローカルLAN副経路。
class LanServer {
  LanServer({required this.shopId, required this.role, int port = 0})
    : _port = port;

  /// 同一店舗フィルタ用の shop_id。mDNS の TXT レコードに含める。
  final String shopId;

  /// 役割（'kitchen' / 'calling' のような文字列、サービス名に含める）。
  final String role;

  int _port;

  HttpServer? _httpServer;
  BonsoirBroadcast? _broadcast;

  final Set<WebSocketChannel> _clients = <WebSocketChannel>{};
  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  Stream<TransportEvent> events() => _events.stream;

  bool get isRunning => _httpServer != null;
  int get port => _port;

  /// サーバを起動して mDNS で公開する。
  Future<void> start() async {
    if (_httpServer != null) {
      return;
    }
    final Handler handler = webSocketHandler(_handleClient);
    _httpServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
    _port = _httpServer!.port;
    AppLogger.event(
      'lan',
      'server_started',
      fields: <String, Object?>{'port': _port},
    );

    final BonsoirService service = BonsoirService(
      name: 'tofu-pos-$role-$shopId',
      type: '_tofu-pos._tcp',
      port: _port,
      attributes: <String, String>{'shopId': shopId, 'role': role},
    );
    final BonsoirBroadcast broadcast = BonsoirBroadcast(service: service);
    await broadcast.initialize();
    await broadcast.start();
    _broadcast = broadcast;
    AppLogger.event(
      'lan',
      'server_broadcasting',
      fields: <String, Object?>{
        'name': service.name,
        'type': service.type,
      },
    );
  }

  Future<void> stop() async {
    final BonsoirBroadcast? b = _broadcast;
    _broadcast = null;
    if (b != null) {
      await b.stop();
    }

    for (final WebSocketChannel c in _clients) {
      await c.sink.close();
    }
    _clients.clear();

    final HttpServer? h = _httpServer;
    _httpServer = null;
    if (h != null) {
      await h.close(force: true);
    }
    await _events.close();
  }

  /// 接続中の全クライアントへブロードキャスト送信。
  Future<void> broadcast(TransportEvent event) async {
    final String wire = LanProtocol.encode(event);
    for (final WebSocketChannel c in _clients) {
      c.sink.add(wire);
    }
  }

  void _handleClient(WebSocketChannel channel, String? subprotocol) {
    AppLogger.d('LanServer: client connected (subprotocol: $subprotocol)');
    _clients.add(channel);
    channel.stream.listen(
      (message) {
        if (message is! String) {
          return;
        }
        try {
          final TransportEvent ev = LanProtocol.decode(message);
          if (ev.shopId != shopId) {
            AppLogger.w(
              'LanServer: ignored event for foreign shopId ${ev.shopId}',
            );
            return;
          }
          _events.add(ev);
        } catch (e, st) {
          AppLogger.w(
            'LanServer: failed to decode message',
            error: e,
            stackTrace: st,
          );
        }
      },
      onDone: () {
        _clients.remove(channel);
        AppLogger.d('LanServer: client disconnected');
      },
      onError: (Object e, StackTrace st) {
        _clients.remove(channel);
        AppLogger.w('LanServer: client error', error: e, stackTrace: st);
      },
      cancelOnError: true,
    );
  }
}
