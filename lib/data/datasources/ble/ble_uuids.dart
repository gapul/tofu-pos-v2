/// BLE GATT で使う Service / Characteristic の UUID 定義（仕様書 §4.1, §4.2）。
class BleUuids {
  BleUuids._();

  // ===== キッチン GATT =====

  /// キッチン端末の Service UUID。
  static const String kitchenService = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

  /// 商品マスタ書き込み（レジ → キッチン、低緊急、§7.3）。
  static const String productMasterWrite =
      '00000002-B5A3-F393-E0A9-E50E24DCCA9E';

  /// 注文書き込み（レジ → キッチン、高緊急）。
  static const String orderWrite = '00000003-B5A3-F393-E0A9-E50E24DCCA9E';

  /// ステータス通知（キッチン → レジ、高緊急）。
  /// ACK と SERVED の両方をこのキャラで notify する（payload で kind を区別）。
  static const String statusNotify = '00000004-B5A3-F393-E0A9-E50E24DCCA9E';

  // ===== 呼び出し GATT =====

  /// 呼び出し端末の Service UUID。
  static const String callingService = '6E40000A-B5A3-F393-E0A9-E50E24DCCA9E';

  /// 整理券番号の書き込み（レジ → 呼び出し、高緊急）。
  static const String callingWrite = '0000000B-B5A3-F393-E0A9-E50E24DCCA9E';
}
