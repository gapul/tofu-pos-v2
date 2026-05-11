/// 注文ステータス（仕様書 §5.2）。
///
/// 状態遷移グラフ:
///   unsent ──► sent ──► served
///     │         │         │
///     ▼         ▼         ▼
///   cancelled (任意の非終端状態から)
///
/// 終端状態: served / cancelled。終端からはどこへも遷移できない。
/// 同一状態への遷移（unsent → unsent 等）は no-op として許可する。
enum OrderStatus {
  /// 未送信（会計確定済みだが、キッチンへ未送信）
  unsent,

  /// 送信済（キッチンが受信したことを確認済み）
  sent,

  /// 提供済（キッチンが提供完了を通知してきた）
  served,

  /// 取消済
  cancelled;

  bool get isTerminal =>
      this == OrderStatus.served || this == OrderStatus.cancelled;

  /// [next] へ遷移可能か。
  bool canTransitionTo(OrderStatus next) {
    if (next == this) return true; // no-op は常に許可
    if (isTerminal) return false; // 終端からはどこへも行けない
    if (next == OrderStatus.cancelled) return true; // 非終端 → cancelled は常に可
    switch (this) {
      case OrderStatus.unsent:
        return next == OrderStatus.sent;
      case OrderStatus.sent:
        return next == OrderStatus.served;
      case OrderStatus.served:
      case OrderStatus.cancelled:
        return false; // unreachable; 上の isTerminal で弾かれる
    }
  }

  /// [next] へ遷移する。不正な遷移は [StateError]。
  ///
  /// 戻り値: [next]（chain しやすいように）。
  OrderStatus transitionTo(OrderStatus next) {
    if (!canTransitionTo(next)) {
      throw StateError(
        'Invalid OrderStatus transition: $name → ${next.name}',
      );
    }
    return next;
  }
}
