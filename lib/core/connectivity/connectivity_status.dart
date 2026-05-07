/// ネットワーク接続状態（仕様書 §7.1）。
///
/// 自動フォールバックは行わないため、これは「現在オンラインで通信可能か」の参考情報。
/// 実際の通信モード（Online / LAN / BLE）は SettingsRepository.transportMode が保持する。
enum ConnectivityStatus {
  online,
  offline;

  bool get isOnline => this == ConnectivityStatus.online;
}
