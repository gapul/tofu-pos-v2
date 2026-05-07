/// 注文ステータス（仕様書 §5.2）。
///
/// 状態遷移:
///   unsent → sent → served
///   * → cancelled（取り消しは任意の状態から可）
enum OrderStatus {
  /// 未送信（会計確定済みだが、キッチンへ未送信）
  unsent,

  /// 送信済（キッチンが受信したことを確認済み）
  sent,

  /// 提供済（キッチンが提供完了を通知してきた）
  served,

  /// 取消済
  cancelled;

  bool get isTerminal => this == OrderStatus.served || this == OrderStatus.cancelled;
}
