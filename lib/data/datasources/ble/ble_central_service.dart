import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/telemetry/telemetry.dart';
import '../../../core/transport/transport_event.dart';
import 'ble_protocol.dart';
import 'ble_uuids.dart';

/// レジ端末（Central）側の BLE 接続管理。
///
/// 仕様書 §4 / §7。同じ shop_id でアドバタイズしている
/// キッチン・呼び出し peripheral にスキャン → 接続 → 書き込み / 通知購読 を行う。
///
/// **未実機検証**: 実機で動かす際に `flutter_blue_plus` の API バージョン依存で
/// 微調整が必要になる可能性あり。
class BleCentralService {
  BleCentralService({
    required this.shopId,
    Duration scanTimeout = const Duration(seconds: 30),
  }) : _scanTimeout = scanTimeout;

  final String shopId;
  final Duration _scanTimeout;

  final Map<String, _ConnectedPeer> _peers = <String, _ConnectedPeer>{};
  StreamSubscription<List<ScanResult>>? _scanSub;
  final BleFrameAssembler _assembler = BleFrameAssembler();
  int _seqCounter = 0;

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  Stream<TransportEvent> events() => _events.stream;
  int get peerCount => _peers.length;

  /// スキャン開始。発見した peripheral へ自動接続。
  ///
  /// 直前まで他 transport で稼働中だった場合に備え、既存スキャンを停止してから開始する。
  /// この transport を生成し直すたびに新しいインスタンスとなるが、
  /// `FlutterBluePlus` 側は singleton なので前回スキャンが残っているケースがある。
  Future<void> start() async {
    final List<Guid> services = <Guid>[
      Guid(BleUuids.kitchenService),
      Guid(BleUuids.callingService),
    ];

    // 前回のスキャンが走っていれば停止（online → bluetooth 切替時の二重起動防止）。
    if (FlutterBluePlus.isScanningNow) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        AppLogger.d('BleCentral: pre-stopScan ignored: $e');
      }
    }

    _scanSub = FlutterBluePlus.scanResults.listen(_onScanResults);
    try {
      await FlutterBluePlus.startScan(
        withServices: services,
        timeout: _scanTimeout,
        continuousUpdates: true,
      );
      Telemetry.instance.event(
        'ble.central.scan_started',
        attrs: <String, Object?>{
          'shop': shopId,
          'services': services.map((g) => g.str).toList(),
        },
      );
    } catch (e, st) {
      Telemetry.instance.error(
        'ble.central.scan_failed',
        error: e,
        stackTrace: st,
        attrs: <String, Object?>{'shop': shopId},
      );
      rethrow;
    }
    AppLogger.event(
      'ble',
      'scan_started',
      fields: <String, Object?>{'shop': shopId},
    );
  }

  Future<void> stop() async {
    try {
      // timeout 経過後は既に停止しており例外を投げるケースがあるため握りつぶす。
      await FlutterBluePlus.stopScan();
    } catch (e) {
      AppLogger.d('BleCentral: stopScan ignored during teardown: $e');
    }
    await _scanSub?.cancel();
    _scanSub = null;
    for (final _ConnectedPeer p in _peers.values) {
      await p.disconnect();
    }
    _peers.clear();
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  /// 全接続中 peripheral へブロードキャスト送信。
  Future<void> broadcast(TransportEvent event) async {
    final int seq = _nextSeq();
    final List<Uint8List> frames = BleProtocol.encode(event, seq: seq);
    for (final _ConnectedPeer peer in _peers.values) {
      try {
        await peer.write(event, frames);
      } catch (e, st) {
        AppLogger.w(
          'BleCentral: write failed to ${peer.remoteId}',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  int _nextSeq() {
    final int s = _seqCounter & 0xff;
    _seqCounter = (_seqCounter + 1) & 0xff;
    return s;
  }

  void _onScanResults(List<ScanResult> results) {
    for (final ScanResult r in results) {
      final String id = r.device.remoteId.str;
      if (_peers.containsKey(id)) continue;

      // shop_id のフィルタリング（advertise の Service Data もしくは ManufacturerData）
      // peripheral 側が Service Data で shopId を載せる前提。
      // 実装簡略化のため、advName に shopId が含まれているかチェックする実装に。
      final String advName = r.advertisementData.advName;
      // 観測のため未マッチも 1 度だけ telemetry に出す。
      Telemetry.instance.event(
        'ble.central.scan_result',
        attrs: <String, Object?>{
          'shop': shopId,
          'remote_id': id,
          'adv_name': advName,
          'matches': advName.contains(shopId),
        },
      );
      if (!advName.contains(shopId)) {
        continue;
      }
      _peers[id] = _ConnectedPeer(this, r.device);
      Telemetry.instance.event(
        'ble.central.peer_found',
        attrs: <String, Object?>{
          'shop': shopId,
          'remote_id': id,
          'adv_name': advName,
        },
      );
      unawaited(_peers[id]!.connect());
    }
  }
}

class _ConnectedPeer {
  _ConnectedPeer(this._owner, this._device);
  final BleCentralService _owner;
  final BluetoothDevice _device;

  String get remoteId => _device.remoteId.str;

  BluetoothCharacteristic? _orderWrite;
  BluetoothCharacteristic? _productMasterWrite;
  BluetoothCharacteristic? _callingWrite;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  Future<void> connect() async {
    try {
      await _device.connect(license: License.free);
      _connSub = _device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          AppLogger.d('BleCentral: $remoteId disconnected');
          _owner._peers.remove(remoteId);
        }
      });
      final List<BluetoothService> services = await _device.discoverServices();
      for (final BluetoothService s in services) {
        if (s.uuid == Guid(BleUuids.kitchenService)) {
          for (final BluetoothCharacteristic c in s.characteristics) {
            if (c.uuid == Guid(BleUuids.orderWrite)) {
              _orderWrite = c;
            } else if (c.uuid == Guid(BleUuids.productMasterWrite)) {
              _productMasterWrite = c;
            } else if (c.uuid == Guid(BleUuids.statusNotify)) {
              await c.setNotifyValue(true);
              _notifySub = c.lastValueStream.listen(_onNotify);
            }
          }
        } else if (s.uuid == Guid(BleUuids.callingService)) {
          for (final BluetoothCharacteristic c in s.characteristics) {
            if (c.uuid == Guid(BleUuids.callingWrite)) {
              _callingWrite = c;
            }
          }
        }
      }
      AppLogger.event(
        'ble',
        'peer_connected',
        fields: <String, Object?>{'remote_id': remoteId},
      );
    } catch (e, st) {
      AppLogger.w(
        'BleCentral: connect failed $remoteId',
        error: e,
        stackTrace: st,
      );
      _owner._peers.remove(remoteId);
    }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    try {
      await _device.disconnect();
    } catch (e) {
      // disconnect() の失敗は既に切断済 / スタック未初期化が大半で無害。
      AppLogger.d(
        'BleCentral: disconnect ignored during teardown: $e',
      );
    }
  }

  /// イベント種別に応じて適切な characteristic に書き込む。
  Future<void> write(TransportEvent event, List<Uint8List> frames) async {
    final BluetoothCharacteristic? target = _selectCharacteristic(event);
    if (target == null) {
      return;
    }
    for (final Uint8List frame in frames) {
      await target.write(frame);
    }
  }

  BluetoothCharacteristic? _selectCharacteristic(TransportEvent event) {
    if (event is OrderSubmittedEvent || event is OrderCancelledEvent) {
      return _orderWrite;
    }
    if (event is ProductMasterUpdateEvent) {
      return _productMasterWrite;
    }
    if (event is CallNumberEvent) {
      return _callingWrite;
    }
    return null;
  }

  void _onNotify(List<int> value) {
    final TransportEvent? ev = _owner._assembler.feed(
      Uint8List.fromList(value),
    );
    if (ev != null) {
      _owner._events.add(ev);
    }
  }
}
