import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_product_repository.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';

void main() {
  late AppDatabase db;
  late DriftProductRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftProductRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsert and findById round-trips a product', () async {
    const Product p = Product(
      id: 'p1',
      name: 'Yakisoba',
      price: Money(400),
      stock: 10,
      displayColor: 0xFFEE7733,
    );
    await repo.upsert(p);

    final Product? loaded = await repo.findById('p1');
    expect(loaded, p);
  });

  test('findAll excludes deleted by default', () async {
    await repo.upsert(const Product(
      id: 'a',
      name: 'A',
      price: Money(100),
      stock: 0,
    ));
    await repo.upsert(const Product(
      id: 'b',
      name: 'B',
      price: Money(200),
      stock: 0,
    ));
    await repo.markDeleted('b');

    final List<Product> active = await repo.findAll();
    expect(active.length, 1);
    expect(active.single.id, 'a');

    final List<Product> all = await repo.findAll(includeDeleted: true);
    expect(all.length, 2);
  });

  test('adjustStock changes stock by delta', () async {
    await repo.upsert(const Product(
      id: 'p',
      name: 'P',
      price: Money(100),
      stock: 5,
    ));
    await repo.adjustStock('p', -2);
    expect((await repo.findById('p'))!.stock, 3);
    await repo.adjustStock('p', 5);
    expect((await repo.findById('p'))!.stock, 8);
  });

  test('adjustStock throws if it would go negative', () async {
    await repo.upsert(const Product(
      id: 'p',
      name: 'P',
      price: Money(100),
      stock: 1,
    ));
    expect(
      () => repo.adjustStock('p', -5),
      throwsStateError,
    );
  });

  test('watchAll emits on changes', () async {
    final Stream<List<Product>> stream = repo.watchAll();
    final List<List<Product>> emissions = <List<Product>>[];
    final sub = stream.listen(emissions.add);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    await repo.upsert(const Product(
      id: 'x',
      name: 'X',
      price: Money(100),
      stock: 0,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(emissions, isNotEmpty);
    expect(emissions.last.length, 1);

    await sub.cancel();
  });
}
