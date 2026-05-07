import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport_event.dart';
import 'lan_protocol.dart';

/// レジ端末側で動かす mDNS ディスカバリ + WebSocket クライアント。
///
/// 同じ shop_id で broadcast している全サーバ（kitchen / calling）に
/// 自動接続し、送受信を多重化する。
class LanClient {
  LanClient({required this.shopId});

  final String shopId;

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySub;

  /// 接続中の peer。key = mDNS service name。
  final Map<String, WebSocketChannel> _peers = <String, WebSocketChannel>{};

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  Stream<TransportEvent> events() => _events.stream;

  int get peerCount => _peers.length;

  Future<void> start() async {
    final BonsoirDiscovery discovery =
        BonsoirDiscovery(type: '_tofu-pos._tcp');
    await discovery.ready;
    await discovery.start();
    _discovery = discovery;

    _discoverySub = discovery.eventStream?.listen(_onDiscovery);
    AppLogger.i('LanClient discovery started for shop=$shopId');
  }

  Future<void> stop() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _discovery?.stop();
    _discovery = null;

    for (final WebSocketChannel ch in _peers.values) {
      await ch.sink.close();
    }
    _peers.clear();

    await _events.close();
  }

  /// 接続中の全 peer に同じイベントを送る（多重ブロードキャスト）。
  Future<void> broadcast(TransportEvent event) async {
    final String wire = LanProtocol.encode(event);
    for (final WebSocketChannel ch in _peers.values) {
      ch.sink.add(wire);
    }
  }

  Future<void> _onDiscovery(BonsoirDiscoveryEvent event) async {
    final BonsoirService? svc = event.service;
    if (svc == null) {
      return;
    }
    if (event.type ==
        BonsoirDiscoveryEventType.discoveryServiceResolved) {
      await _connectToPeer(svc);
    } else if (event.type ==
        BonsoirDiscoveryEventType.discoveryServiceLost) {
      _peers.remove(svc.name);
      AppLogger.d('LanClient: peer lost ${svc.name}');
    }
  }

  Future<void> _connectToPeer(BonsoirService service) async {
    final String? peerShop =
        service.attributes['shopId'] ?? service.attributes['shop_id'];
    if (peerShop != shopId) {
      AppLogger.d('LanClient: ignored peer with shopId=$peerShop');
      return;
    }
    if (_peers.containsKey(service.name)) {
      return;
    }

    final ResolvedBonsoirService? resolved =
        service is ResolvedBonsoirService ? service : null;
    final String? host = resolved?.host;
    if (host == null) {
      AppLogger.w('LanClient: no host on resolved service ${service.name}');
      return;
    }
    final Uri uri = Uri.parse('ws://$host:${service.port}');
    try {
      final WebSocketChannel ch = WebSocketChannel.connect(uri);
      _peers[service.name] = ch;
      AppLogger.i('LanClient: connected to ${service.name} @ $uri');
      ch.stream.listen(
        (Object? message) {
          if (message is! String) {
            return;
          }
          try {
            final TransportEvent ev = LanProtocol.decode(message);
            if (ev.shopId != shopId) {
              return;
            }
            _events.add(ev);
          } catch (e, st) {
            AppLogger.w('LanClient: decode failed',
                error: e, stackTrace: st);
          }
        },
        onDone: () {
          _peers.remove(service.name);
          AppLogger.d('LanClient: disconnected from ${service.name}');
        },
        onError: (Object e, StackTrace st) {
          _peers.remove(service.name);
          AppLogger.w('LanClient: peer error',
              error: e, stackTrace: st);
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      AppLogger.w('LanClient: failed to connect to $uri',
          error: e, stackTrace: st);
    }
  }
}
