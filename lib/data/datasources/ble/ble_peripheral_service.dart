// role により kitchen 用 / calling 用で生成する characteristic が変わるため、
// nullable のまま保持する必要がある（late final が使えない）。
// ignore_for_file: use_late_for_private_fields_and_variables

import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport_event.dart';
import 'ble_protocol.dart';
import 'ble_uuids.dart';

/// キッチン・呼び出し端末（Peripheral）側の BLE GATT サーバ。
///
/// 仕様書 §4.1 / §4.2 の UUID で Service と Characteristic を公開し、
/// Advertisement の serviceUUIDs と name に shopId を埋めて Central に識別させる。
///
/// `bluetooth_low_energy` パッケージを使用（iOS/Android/macOS 対応）。
/// **未実機検証**: 実装は API 仕様準拠だが、実機での挙動確認は別途必要。
class BlePeripheralService {
  BlePeripheralService({
    required this.shopId,
    required this.role, // 'kitchen' or 'calling'
  });

  final String shopId;
  final String role;

  final PeripheralManager _manager = PeripheralManager();

  GATTService? _service;
  GATTCharacteristic? _orderWriteChar;
  GATTCharacteristic? _productMasterWriteChar;
  GATTCharacteristic? _statusNotifyChar;
  GATTCharacteristic? _callingWriteChar;

  /// この characteristic に notify を購読中の central の一覧。
  /// notify を送るときは、ここに登録された central にだけ送る。
  final Map<GATTCharacteristic, Set<Central>> _subscribers =
      <GATTCharacteristic, Set<Central>>{};

  StreamSubscription<GATTCharacteristicWriteRequestedEventArgs>? _writeSub;
  StreamSubscription<GATTCharacteristicNotifyStateChangedEventArgs>? _notifySub;

  final BleFrameAssembler _assembler = BleFrameAssembler();
  int _seqCounter = 0;
  bool _started = false;

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  Stream<TransportEvent> events() => _events.stream;
  bool get isStarted => _started;
  bool get isKitchen => role == 'kitchen';

  Future<void> start() async {
    if (_started) {
      return;
    }
    if (kIsWeb) {
      AppLogger.w('BlePeripheral: not supported on web');
      return;
    }

    // Android のみ authorize 必要、他プラットフォームは UnsupportedError を投げる。
    try {
      await _manager.authorize();
    } catch (_) {
      // iOS/macOS は UnsupportedError を投げるが致命ではない
    }

    if (_manager.state != BluetoothLowEnergyState.poweredOn) {
      AppLogger.w(
        'BlePeripheral: BLE not powered on (state=${_manager.state})',
      );
      return;
    }

    _buildService();
    await _manager.addService(_service!);

    _writeSub = _manager.characteristicWriteRequested.listen(_onWriteRequest);
    _notifySub = _manager.characteristicNotifyStateChanged.listen(
      _onNotifyStateChanged,
    );

    final UUID serviceUuid = _service!.uuid;
    await _manager.startAdvertising(
      Advertisement(
        name: 'tofu-pos:$role:$shopId',
        serviceUUIDs: <UUID>[serviceUuid],
      ),
    );

    _started = true;
    AppLogger.i(
      'BlePeripheral started: role=$role shopId=$shopId service=$serviceUuid',
    );
  }

  Future<void> stop() async {
    if (!_started) {
      return;
    }
    try {
      await _manager.stopAdvertising();
    } catch (e, st) {
      AppLogger.w(
        'BlePeripheral: stopAdvertising failed',
        error: e,
        stackTrace: st,
      );
    }
    try {
      await _manager.removeAllServices();
    } catch (e) {
      // 停止経路で BLE スタックが既に解放されている場合の例外は想定内。
      AppLogger.d(
        'BlePeripheral: removeAllServices ignored during teardown: $e',
      );
    }

    await _writeSub?.cancel();
    _writeSub = null;
    await _notifySub?.cancel();
    _notifySub = null;
    _subscribers.clear();
    _started = false;
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  /// 購読中の全 central に notify を送る。
  ///
  /// キッチン役: statusNotify 経由で送信。
  /// 呼び出し役: notify 用 characteristic を持たないため何もしない（仕様準拠）。
  Future<void> broadcast(TransportEvent event) async {
    final GATTCharacteristic? notifyChar = _statusNotifyChar;
    if (notifyChar == null) {
      return;
    }
    final Set<Central>? subs = _subscribers[notifyChar];
    if (subs == null || subs.isEmpty) {
      return;
    }

    final int seq = _nextSeq();
    final List<Uint8List> frames = BleProtocol.encode(event, seq: seq);
    for (final Central c in subs) {
      for (final Uint8List frame in frames) {
        try {
          await _manager.notifyCharacteristic(c, notifyChar, value: frame);
        } catch (e, st) {
          AppLogger.w('BlePeripheral: notify failed', error: e, stackTrace: st);
        }
      }
    }
  }

  // ===== internal =====

  void _buildService() {
    if (isKitchen) {
      _orderWriteChar = GATTCharacteristic.mutable(
        uuid: UUID.fromString(BleUuids.orderWrite),
        properties: <GATTCharacteristicProperty>[
          GATTCharacteristicProperty.write,
          GATTCharacteristicProperty.writeWithoutResponse,
        ],
        permissions: <GATTCharacteristicPermission>[
          GATTCharacteristicPermission.write,
        ],
        descriptors: <GATTDescriptor>[],
      );
      _productMasterWriteChar = GATTCharacteristic.mutable(
        uuid: UUID.fromString(BleUuids.productMasterWrite),
        properties: <GATTCharacteristicProperty>[
          GATTCharacteristicProperty.write,
          GATTCharacteristicProperty.writeWithoutResponse,
        ],
        permissions: <GATTCharacteristicPermission>[
          GATTCharacteristicPermission.write,
        ],
        descriptors: <GATTDescriptor>[],
      );
      _statusNotifyChar = GATTCharacteristic.mutable(
        uuid: UUID.fromString(BleUuids.statusNotify),
        properties: <GATTCharacteristicProperty>[
          GATTCharacteristicProperty.notify,
        ],
        permissions: <GATTCharacteristicPermission>[],
        descriptors: <GATTDescriptor>[],
      );
      _service = GATTService(
        uuid: UUID.fromString(BleUuids.kitchenService),
        isPrimary: true,
        includedServices: <GATTService>[],
        characteristics: <GATTCharacteristic>[
          _orderWriteChar!,
          _productMasterWriteChar!,
          _statusNotifyChar!,
        ],
      );
    } else {
      _callingWriteChar = GATTCharacteristic.mutable(
        uuid: UUID.fromString(BleUuids.callingWrite),
        properties: <GATTCharacteristicProperty>[
          GATTCharacteristicProperty.write,
          GATTCharacteristicProperty.writeWithoutResponse,
        ],
        permissions: <GATTCharacteristicPermission>[
          GATTCharacteristicPermission.write,
        ],
        descriptors: <GATTDescriptor>[],
      );
      _service = GATTService(
        uuid: UUID.fromString(BleUuids.callingService),
        isPrimary: true,
        includedServices: <GATTService>[],
        characteristics: <GATTCharacteristic>[_callingWriteChar!],
      );
    }
  }

  Future<void> _onWriteRequest(
    GATTCharacteristicWriteRequestedEventArgs args,
  ) async {
    try {
      final TransportEvent? ev = _assembler.feed(
        Uint8List.fromList(args.request.value),
      );
      if (ev != null && ev.shopId == shopId) {
        _events.add(ev);
      }
      await _manager.respondWriteRequest(args.request);
    } catch (e, st) {
      AppLogger.w(
        'BlePeripheral: write handling failed',
        error: e,
        stackTrace: st,
      );
      try {
        await _manager.respondWriteRequestWithError(
          args.request,
          error: GATTError.unlikelyError,
        );
      } catch (e2) {
        // エラー応答自体の失敗は接続がすでに切れているケースが大半。
        AppLogger.d(
          'BlePeripheral: respondWriteRequestWithError ignored: $e2',
        );
      }
    }
  }

  void _onNotifyStateChanged(
    GATTCharacteristicNotifyStateChangedEventArgs args,
  ) {
    final Set<Central> subs = _subscribers.putIfAbsent(
      args.characteristic,
      () => <Central>{},
    );
    if (args.state) {
      subs.add(args.central);
      AppLogger.d('BlePeripheral: central ${args.central} subscribed');
    } else {
      subs.remove(args.central);
      AppLogger.d('BlePeripheral: central ${args.central} unsubscribed');
    }
  }

  int _nextSeq() {
    final int s = _seqCounter & 0xff;
    _seqCounter = (_seqCounter + 1) & 0xff;
    return s;
  }
}
