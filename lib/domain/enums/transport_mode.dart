/// 端末間通信の経路モード（仕様書 §7.1）。
///
/// 切替はユーザーの手動操作で行う（自動フォールバックしない）。
enum TransportMode {
  /// インターネット経由（Supabase Realtime）
  online,

  /// ローカルLAN（mDNS + WebSocket）
  localLan,

  /// BLE（最後の砦）
  bluetooth,
}
