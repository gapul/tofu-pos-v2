import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_cash_drawer_repository.dart';
import 'package:tofu_pos/domain/entities/cash_drawer.dart';
import 'package:tofu_pos/domain/value_objects/denomination.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';

void main() {
  late AppDatabase db;
  late DriftCashDrawerRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftCashDrawerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('starts empty', () async {
    final CashDrawer drawer = await repo.get();
    expect(drawer.totalAmount, Money.zero);
  });

  test('apply adds and subtracts', () async {
    await repo.apply(<Denomination, int>{
      const Denomination(1000): 5,
      const Denomination(100): 10,
    });
    final CashDrawer drawer = await repo.get();
    expect(drawer.totalAmount, const Money(6000));

    await repo.apply(<Denomination, int>{const Denomination(100): -3});
    expect((await repo.get()).countOf(const Denomination(100)), 7);
  });

  test('apply throws on negative', () async {
    expect(
      () => repo.apply(<Denomination, int>{const Denomination(100): -1}),
      throwsStateError,
    );
  });

  test('replace overwrites all denominations', () async {
    await repo.apply(<Denomination, int>{const Denomination(100): 10});
    final CashDrawer fresh = CashDrawer(<Denomination, int>{
      const Denomination(1000): 3,
    });
    await repo.replace(fresh);

    final CashDrawer drawer = await repo.get();
    expect(drawer.countOf(const Denomination(100)), 0);
    expect(drawer.countOf(const Denomination(1000)), 3);
  });
}
