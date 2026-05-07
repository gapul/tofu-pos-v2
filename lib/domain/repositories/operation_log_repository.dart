import '../entities/operation_log.dart';

/// 操作ログ Repository（仕様書 §6.6）。
///
/// 取消等の操作を「誰がいつ何をしたか」の形で監査用に記録する。
/// ログは消去できないものとする（信用ベース制御の根拠となる）。
abstract interface class OperationLogRepository {
  Future<void> record({
    required String kind,
    String? targetId,
    String? detailJson,
    DateTime? at,
  });

  Future<List<OperationLog>> findRecent({int limit = 100});
}
