import 'package:meta/meta.dart';

/// 操作ログの種別キー（仕様書 §6.6）。
///
/// `OperationLog.kind` は string で持つが、業務側コード / UI が依存する値は
/// ここに集約し typo / drift を防ぐ。新規追加時はこの定数に追記し、
/// schema migration が不要な範囲（kind 列は text のまま）で運用する。
abstract final class OperationKind {
  /// 注文取消（CancelOrderUseCase）。
  static const String cancelOrder = 'cancel_order';

  /// 注文確定（CheckoutUseCase）。
  static const String checkout = 'checkout';

  /// レジ締め（CashCloseUseCase）。差額情報を detailJson に記録する。
  static const String cashClose = 'cash_close';

  /// 金種補充/置換（CashDrawerRepository.replace 経由）。
  static const String cashDrawerReplace = 'cash_drawer_replace';

  /// 日次リセット（DailyResetUseCase）。
  static const String dailyReset = 'daily_reset';

  /// 商品マスタ更新（既存）。
  static const String productMasterUpdate = 'product_master_update';
}

/// 操作ログ（仕様書 §6.6 信用ベース制御の根拠となる監査ログ）。
@immutable
class OperationLog {
  const OperationLog({
    required this.id,
    required this.kind,
    required this.occurredAt,
    this.targetId,
    this.detailJson,
  });

  final int id;

  /// 操作種別。例: 'cancel_order', 'product_master_update', 'cash_drawer_replace'
  final String kind;

  /// 関連リソースID（例: 注文ID）
  final String? targetId;

  /// 操作詳細のJSON
  final String? detailJson;

  final DateTime occurredAt;

  @override
  String toString() =>
      'OperationLog(#$id $kind target=$targetId at=$occurredAt)';
}
