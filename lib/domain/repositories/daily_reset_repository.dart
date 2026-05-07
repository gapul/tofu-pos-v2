/// 「最終営業日」を保持する小さな Repository。
///
/// 仕様書 §6.4 営業日の区切りで、整理券プールを日付変更時にリセットするために使う。
abstract interface class DailyResetRepository {
  /// 直近に DailyReset を実行した日（端末ローカル日付）。未記録なら null。
  Future<DateTime?> getLastResetDate();

  /// 指定の日付に更新する。時刻部分は無視する想定。
  Future<void> setLastResetDate(DateTime date);
}
