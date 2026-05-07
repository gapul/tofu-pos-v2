import 'package:meta/meta.dart';

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
