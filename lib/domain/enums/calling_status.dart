/// 呼び出し端末側のステータス（仕様書 §5.6）。
enum CallingStatus {
  /// 呼び出し前
  pending,

  /// 呼び出し済み
  called,

  /// 取消（レジから取消通知を受けた）
  cancelled,
}
