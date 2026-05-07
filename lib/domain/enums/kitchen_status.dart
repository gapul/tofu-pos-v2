/// キッチン端末側の調理ステータス（仕様書 §5.5）。
///
/// レジ側の OrderStatus とは別概念のため意図的に分けている。
enum KitchenStatus {
  /// 未調理
  pending,

  /// 提供完了
  done,

  /// 取消（レジから「調理中止」通知を受けた）
  cancelled,
}
