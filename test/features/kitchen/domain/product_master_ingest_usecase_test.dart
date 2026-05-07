import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/features/kitchen/domain/product_master_ingest_usecase.dart';

import '../../../fakes/fake_repositories.dart';

void main() {
  test('ingest replaces local catalog with received list', () async {
    final repo = InMemoryProductRepository(<Product>[
      const Product(id: 'old', name: 'Old', price: Money(100), stock: 1),
    ]);
    final u = ProductMasterIngestUseCase(productRepository: repo);

    await u.ingest(ProductMasterUpdateEvent(
      shopId: 'shop',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      productsJson: '['
          '{"id":"new1","name":"New 1","price_yen":300,"stock":5},'
          '{"id":"new2","name":"New 2","price_yen":500,"stock":2,"display_color":4294934784}'
          ']',
    ));

    final all = await repo.findAll();
    expect(all.map((p) => p.id), unorderedEquals(<String>['new1', 'new2']));
    expect(all.firstWhere((p) => p.id == 'new1').price, const Money(300));
    expect(all.firstWhere((p) => p.id == 'new2').displayColor, 4294934784);

    // 古い 'old' は論理削除
    final withDeleted = await repo.findAll(includeDeleted: true);
    final old = withDeleted.firstWhere((p) => p.id == 'old');
    expect(old.isDeleted, isTrue);
  });

  test('ingest accepts empty list (clears catalog)', () async {
    final repo = InMemoryProductRepository(<Product>[
      const Product(id: 'p1', name: 'P', price: Money(100), stock: 1),
    ]);
    final u = ProductMasterIngestUseCase(productRepository: repo);
    await u.ingest(ProductMasterUpdateEvent(
      shopId: 'shop',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      productsJson: '[]',
    ));
    final visible = await repo.findAll();
    expect(visible, isEmpty);
  });
}
