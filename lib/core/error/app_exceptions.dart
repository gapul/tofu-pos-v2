/// アプリ全体で使う例外階層。
///
/// UseCase / Repository が投げ、Presentation 層がユーザーに翻訳する。
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 整理券プールが満杯で新規発番不可（仕様書 §5.2）。
class TicketPoolExhaustedException extends AppException {
  const TicketPoolExhaustedException()
      : super('整理券番号の空きがありません。提供済み番号が再利用可能になるまでお待ちください。');
}

/// 在庫不足。
class InsufficientStockException extends AppException {
  const InsufficientStockException(this.productName, this.requested, this.available)
      : super('在庫が不足しています');

  final String productName;
  final int requested;
  final int available;

  @override
  String toString() =>
      'InsufficientStockException: $productName は $available 個しかありません（要求: $requested）';
}

/// 取消対象の注文が見つからない／既に取消済み等。
class OrderNotCancellableException extends AppException {
  const OrderNotCancellableException(super.message);
}

/// 端末間通信の高緊急情報の送達失敗（仕様書 §7.2）。
class TransportDeliveryException extends AppException {
  const TransportDeliveryException(super.message);
}

/// 設定が未完了で操作不可（店舗ID未設定等）。
class SetupIncompleteException extends AppException {
  const SetupIncompleteException(super.message);
}
