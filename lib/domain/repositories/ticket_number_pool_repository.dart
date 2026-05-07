import '../value_objects/ticket_number_pool.dart';

/// 整理券プールの永続化抽象（仕様書 §5.2 / §11）。
///
/// アプリ再起動・日付切替を跨いで状態を保持する。
abstract interface class TicketNumberPoolRepository {
  Future<TicketNumberPool> load();
  Future<void> save(TicketNumberPool pool);
}
