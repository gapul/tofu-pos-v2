/// アプリ全体で使う例外階層。
///
/// UseCase / Repository が投げ、Presentation 層がユーザーに翻訳する。
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  /// 例外種別を表す静的な名前（サブクラスで上書き）。
  /// runtimeType.toString() は dart2js 環境で minify されるため使わない。
  String get kind => 'AppException';

  @override
  String toString() => '$kind: $message';
}

/// 整理券プールが満杯で新規発番不可（仕様書 §5.2）。
class TicketPoolExhaustedException extends AppException {
  const TicketPoolExhaustedException()
    : super('整理券番号の空きがありません。提供済み番号が再利用可能になるまでお待ちください。');

  @override
  String get kind => 'TicketPoolExhaustedException';
}

/// 在庫不足。
class InsufficientStockException extends AppException {
  const InsufficientStockException(
    this.productName,
    this.requested,
    this.available,
  ) : super('在庫が不足しています');

  final String productName;
  final int requested;
  final int available;

  @override
  String get kind => 'InsufficientStockException';

  @override
  String toString() =>
      '$kind: $productName は $available 個しかありません（要求: $requested）';
}

/// 取消対象の注文が見つからない／既に取消済み等。
class OrderNotCancellableException extends AppException {
  const OrderNotCancellableException(super.message);

  @override
  String get kind => 'OrderNotCancellableException';
}

/// 端末間通信の高緊急情報の送達失敗（仕様書 §7.2）。
class TransportDeliveryException extends AppException {
  const TransportDeliveryException(super.message);

  @override
  String get kind => 'TransportDeliveryException';
}

/// 不正な状態遷移（OrderStatus 等の state machine 違反）。
class InvalidStateTransitionException extends AppException {
  const InvalidStateTransitionException(
    super.message, {
    required this.from,
    required this.to,
  });

  /// 現在状態（例: 'served'）。
  final String from;

  /// 試行された遷移先（例: 'sent'）。
  final String to;

  @override
  String get kind => 'InvalidStateTransitionException';

  @override
  String toString() => '$kind: $message (from=$from, to=$to)';
}

/// 設定が未完了で操作不可（店舗ID未設定等）。
class SetupIncompleteException extends AppException {
  const SetupIncompleteException(super.message);

  @override
  String get kind => 'SetupIncompleteException';
}
