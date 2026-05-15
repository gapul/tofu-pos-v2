import 'dart:async';

import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/enums/device_role.dart';
import '../logging/app_logger.dart';

/// 1 端末を識別する presence エントリ。
@immutable
class PeerInfo {
  const PeerInfo({required this.role, required this.deviceId});

  final DeviceRole role;
  final String deviceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerInfo &&
          role == other.role &&
          deviceId == other.deviceId);

  @override
  int get hashCode => Object.hash(role, deviceId);

  @override
  String toString() => 'PeerInfo(role=$role, deviceId=$deviceId)';
}

/// Supabase Realtime Presence を使って同一店舗内の他端末状況を取得するサービス。
///
/// 起動時に `tofu-pos:presence:$shopId` チャンネルに `track({role, device_id})`
/// を送信し、他端末からの `sync` イベントを受信して [peers] Stream に流す。
class PeerPresenceService {
  PeerPresenceService({
    required SupabaseClient client,
    required this.shopId,
    required this.role,
    required this.deviceId,
  }) : _client = client;

  final SupabaseClient _client;
  final String shopId;
  final DeviceRole role;
  final String deviceId;

  RealtimeChannel? _channel;
  final StreamController<List<PeerInfo>> _peersController =
      StreamController<List<PeerInfo>>.broadcast();
  List<PeerInfo> _lastPeers = const <PeerInfo>[];

  /// 接続中の全端末リスト（自分自身を含む）。`sync` 受信のたびに emit。
  Stream<List<PeerInfo>> get peers async* {
    yield _lastPeers;
    yield* _peersController.stream;
  }

  /// 直近の peers スナップショット。初回 sync 前は空。
  List<PeerInfo> get currentPeers => _lastPeers;

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    if (_channel != null) return;
    final RealtimeChannel ch = _client.channel(
      'tofu-pos:presence:$shopId',
      opts: RealtimeChannelConfig(key: deviceId),
    );
    ch
        .onPresenceSync((_) {
          _emitSync(ch);
        })
        .onPresenceJoin((_) {
          _emitSync(ch);
        })
        .onPresenceLeave((_) {
          _emitSync(ch);
        });
    _channel = ch;
    ch.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await ch.track(<String, dynamic>{
            'role': role.name,
            'device_id': deviceId,
          });
        } catch (e, st) {
          AppLogger.w(
            'PeerPresence: track failed',
            error: e,
            stackTrace: st,
          );
        }
      } else if (error != null) {
        AppLogger.w('PeerPresence: subscribe error', error: error);
      }
    });
  }

  void _emitSync(RealtimeChannel ch) {
    try {
      final List<SinglePresenceState> states = ch.presenceState();
      final List<PeerInfo> peers = <PeerInfo>[];
      final Set<String> seen = <String>{};
      for (final SinglePresenceState s in states) {
        for (final Presence p in s.presences) {
          final Map<String, dynamic> payload = p.payload;
          final String? roleStr = payload['role'] as String?;
          final String? did = payload['device_id'] as String?;
          if (roleStr == null || did == null) continue;
          final DeviceRole? r = DeviceRole.values
              .where((e) => e.name == roleStr)
              .cast<DeviceRole?>()
              .firstWhere((_) => true, orElse: () => null);
          if (r == null) continue;
          if (!seen.add(did)) continue;
          peers.add(PeerInfo(role: r, deviceId: did));
        }
      }
      _lastPeers = peers;
      _peersController.add(peers);
    } catch (e, st) {
      AppLogger.w('PeerPresence: sync parse failed', error: e, stackTrace: st);
    }
  }

  Future<void> disconnect() async {
    final RealtimeChannel? ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        await ch.untrack();
      } catch (_) {
        // ignore — closing anyway
      }
      try {
        await _client.removeChannel(ch);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _peersController.close();
  }
}
