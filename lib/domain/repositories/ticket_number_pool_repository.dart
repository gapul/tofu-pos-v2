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
}
