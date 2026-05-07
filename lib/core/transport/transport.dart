import 'package:tofu_pos/core/error/app_exceptions.dart'
    show TransportDeliveryException;

import 'transport_event.dart';

/// 端末間通信の抽象（仕様書 §7）。
///
/// 実装:
///  - SupabaseTransport（オンライン主経路）
///  - LanTransport（ローカルLAN副経路）
///  - BleTransport（最後の砦）
///
/// 高緊急イベントは ACK 必須・タイムアウト時に [TransportDeliveryException] を投げる。
/// 低緊急イベントは静かに再試行する（例外を投げない）。
abstract interface class Transport {
  /// イベントを送信する。送信戦略は実装に委ねる。
  Future<void> send(TransportEvent event);

  /// 受信イベントを購読。
  Stream<TransportEvent> events();

  /// 起動・接続。
  Future<void> connect();

  /// 切断・クリーンアップ。
  Future<void> disconnect();
}
