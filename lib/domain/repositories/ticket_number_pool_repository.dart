import '../value_objects/ticket_number.dart';
import '../value_objects/ticket_number_pool.dart';

/// 整理券プールの永続化抽象（仕様書 §5.2 / §11）。
///
/// アプリ再起動・日付切替を跨いで状態を保持する。
///
/// 並行性: 単一プロセス内で `allocate` / `release` が並行呼び出しされても、
/// `load -> issue -> save` がシリアライズされ、同じ番号が複数発行されないこと。
abstract interface class TicketNumberPoolRepository {
  Future<TicketNumberPool> load();
  Future<void> save(TicketNumberPool pool);

  /// 番号を1件発番してプールを永続化する。
  /// 空きがなければ [StateError]。
  Future<TicketNumber> allocate();

  /// 番号を解放してプールを永続化する。すでに使用中でない番号は no-op。
  Future<void> release(TicketNumber number);

  /// 日次リセット用。プールを完全初期化する（使用中・バッファ含めて空）。
  /// 並行する allocate / release とも直列化される。
  Future<void> reset();

  /// 補償用の release が失敗したときに「あとで解放するべき番号」を積むキュー。
  /// 起動時に [flushPendingReleases] が消化する。
  Future<void> enqueuePendingRelease(TicketNumber number);

  /// 現在キューに積まれている未処理 release の一覧（テスト・診断用）。
  Future<List<TicketNumber>> pendingReleases();

  /// 起動時に呼ばれ、キューに積まれている release を順次実行する。
  /// 1 件でも消化に失敗したら次回まで残す（ロスト防止）。
  /// 戻り値: 消化に成功した件数。
  Future<int> flushPendingReleases();
}
