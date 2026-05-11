import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/repositories/product_repository.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';

/// ProductRepository の契約テスト。
void runProductRepositoryContract(
  String label, {
  required Future<ProductRepository> Function() create,
  Future<void> Function()? cleanup,
}) {
  group('ProductRepository contract: $label', () {
    late ProductRepository repo;

    setUp(() async {
      repo = await create();
    });

    if (cleanup != null) {
      tearDown(cleanup);
    }

    test('upsert and findById round-trips', () async {
      const Product p = Product(
        id: 'p1',
        name: 'A',
        price: Money(100),
        stock: 5,
      );
      await repo.upsert(p);
      final Product? loaded = await repo.findById('p1');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'p1');
      expect(loaded.name, 'A');
      expect(loaded.price, const Money(100));
    });

    test('findById returns null for unknown id', () async {
      final Product? p = await repo.findById('nope');
      expect(p, isNull);
    });

    test('findAll excludes deleted by default', () async {
      await repo.upsert(
        const Product(id: 'a', name: 'A', price: Money(100), stock: 0),
      );
      await repo.upsert(
        const Product(id: 'b', name: 'B', price: Money(200), stock: 0),
      );
      await repo.markDeleted('b');
      final List<Product> active = await repo.findAll();
      expect(active.map((p) => p.id).toSet(), <String>{'a'});
    });

    test('findAll includes deleted when includeDeleted=true', () async {
      await repo.upsert(
        const Product(id: 'a', name: 'A', price: Money(100), stock: 0),
      );
      await repo.markDeleted('a');
      final List<Product> all = await repo.findAll(includeDeleted: true);
      expect(all.map((p) => p.id).toSet().contains('a'), isTrue);
    });

    test('upsert overwrites existing product', () async {
      await repo.upsert(
        const Product(id: 'a', name: 'A', price: Money(100), stock: 0),
      );
      await repo.upsert(
        const Product(id: 'a', name: 'A2', price: Money(200), stock: 0),
      );
      final Product? p = await repo.findById('a');
      expect(p!.name, 'A2');
      expect(p.price, const Money(200));
    });

    test('adjustStock applies delta', () async {
      await repo.upsert(
        const Product(id: 'a', name: 'A', price: Money(100), stock: 10),
      );
      await repo.adjustStock('a', -3);
      final Product? p = await repo.findById('a');
      expect(p!.stock, 7);
    });

    test('adjustStock on unknown id throws StateError', () async {
      expect(
        () => repo.adjustStock('nope', -1),
        throwsStateError,
      );
    });

    test('replaceAll soft-deletes products not in the new list', () async {
      await repo.upsert(
        const Product(id: 'a', name: 'A', price: Money(100), stock: 0),
      );
      await repo.upsert(
        const Product(id: 'b', name: 'B', price: Money(100), stock: 0),
      );
      await repo.replaceAll(const <Product>[
        Product(id: 'a', name: 'A', price: Money(100), stock: 0),
      ]);
      final List<Product> active = await repo.findAll();
      expect(active.map((p) => p.id).toSet(), <String>{'a'});
      final Product? bAll = await repo.findById('b');
      expect(bAll, isNotNull);
      expect(bAll!.isDeleted, isTrue);
    });

    test('markDeleted on unknown id does not throw', () async {
      await repo.markDeleted('unknown_id_xyz');
    });
  });
}
