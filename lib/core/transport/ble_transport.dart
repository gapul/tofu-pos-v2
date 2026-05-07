import '../../data/datasources/ble/ble_central_service.dart';
import '../../data/datasources/ble/ble_peripheral_service.dart';
import 'transport.dart';
import 'transport_event.dart';

/// BLE 経由の Transport（仕様書 §7.1 最後の砦）。
///
/// LAN フォールバックでも繋がらない極端なケース（会場の Wi-Fi が完全に死んでいる、
/// モバイルルーターが故障した等）に備える。
///
/// 役割により内部実装を切り替える:
///  - レジ: [BleCentralService]（スキャン + 接続 + 書き込み + Notify購読）
///  - キッチン/呼び出し: [BlePeripheralService]（GATT サーバ + Advertise）
class BleTransport implements Transport {
  BleTransport.central(BleCentralService central) : _impl = _CentralImpl(central);
  BleTransport.peripheral(BlePeripheralService peripheral)
      : _impl = _PeripheralImpl(peripheral);

  final _BleImpl _impl;

  @override
  Future<void> connect() => _impl.connect();

  @override
  Future<void> disconnect() => _impl.disconnect();

  @override
  Stream<TransportEvent> events() => _impl.events();

  @override
  Future<void> send(TransportEvent event) => _impl.send(event);
}

abstract class _BleImpl {
  Future<void> connect();
  Future<void> disconnect();
  Stream<TransportEvent> events();
  Future<void> send(TransportEvent event);
}

class _CentralImpl implements _BleImpl {
  _CentralImpl(this._service);
  final BleCentralService _service;

  @override
  Future<void> connect() => _service.start();

  @override
  Future<void> disconnect() => _service.stop();

  @override
  Stream<TransportEvent> events() => _service.events();

  @override
  Future<void> send(TransportEvent event) => _service.broadcast(event);
}

class _PeripheralImpl implements _BleImpl {
  _PeripheralImpl(this._service);
  final BlePeripheralService _service;

  @override
  Future<void> connect() => _service.start();

  @override
  Future<void> disconnect() => _service.stop();

  @override
  Stream<TransportEvent> events() => _service.events();

  @override
  Future<void> send(TransportEvent event) => _service.broadcast(event);
}
