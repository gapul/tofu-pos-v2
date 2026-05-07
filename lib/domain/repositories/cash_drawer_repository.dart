import '../entities/cash_drawer.dart';
import '../value_objects/denomination.dart';

abstract interface class CashDrawerRepository {
  Future<CashDrawer> get();
  Stream<CashDrawer> watch();

  /// 金種別差分を適用（負で減算）。
  Future<void> apply(Map<Denomination, int> delta);

  /// 全金種を上書き保存（初期化用）。
  Future<void> replace(CashDrawer drawer);
}
