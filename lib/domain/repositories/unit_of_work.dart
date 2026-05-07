/// 不可分（atomic）な処理の実行単位。
///
/// 仕様書 §6.1.4 / §6.6 の「不可分単位で実行」を保証する。
/// Data 層では DB トランザクションで実装される。
abstract interface class UnitOfWork {
  Future<T> run<T>(Future<T> Function() body);
}
