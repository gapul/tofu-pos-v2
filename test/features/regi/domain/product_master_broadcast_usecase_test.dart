import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/noop_transport.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/features/regi/domain/product_master_broadcast_usecase.dart';

import '../../../fakes/fake_repositories.dart';

class _FailingTransport implements Transport {
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Stream<TransportEvent> events() => const Stream<TransportEvent>.empty();
  @override
  Future<void> send(TransportEvent event) {
    throw StateError('boom');
  }
}

void main() {
  test('sends ProductMasterUpdateEvent with all products as JSON', () async {
    final InMemoryProductRepository repo = InMemoryProductRepository(<Product>[
      const Product(
        id: 'p1',
        name: 'Yakisoba',
        price: Money(400),
        stock: 10,
        displayColor: 0xFFEE7733,
      ),
      const Product(id: 'p2', name: 'Juice', price: Money(150), stock: 20),
    ]);
    final NoopTransport transport = NoopTransport();
    final ProductMasterBroadcastUseCase u = ProductMasterBroadcastUseCase(
      productRepository: repo,
      transport: transport,
      shopId: 'shop_a',
      now: () => DateTime.utc(2026, 5, 7, 12),
    );

    await u.execute();
    expect(transport.sent, hasLength(1));
    final ProductMasterUpdateEvent ev =
        transport.sent.single as ProductMasterUpdateEvent;
    expect(ev.shopId, 'shop_a');
    expect(ev.isHighPriority, isFalse);
    expect(ev.productsJson, contains('Yakisoba'));
    expect(ev.productsJson, contains('Juice'));
    expect(ev.productsJson, contains('"price_yen":400'));
  });

  test('does not throw on transport failure (low priority)', () async {
    final InMemoryProductRepository repo = InMemoryProductRepository(<Product>[
      const Product(id: 'p', name: 'P', price: Money(100), stock: 1),
    ]);
    final ProductMasterBroadcastUseCase u = ProductMasterBroadcastUseCase(
      productRepository: repo,
      transport: _FailingTransport(),
      shopId: 'shop_a',
    );
    // 失敗しても例外を投げない（低緊急）
    await u.execute();
  });

  test('sends empty array when no products', () async {
    final InMemoryProductRepository repo =
        InMemoryProductRepository(<Product>[]);
    final NoopTransport transport = NoopTransport();
    final ProductMasterBroadcastUseCase u = ProductMasterBroadcastUseCase(
      productRepository: repo,
      transport: transport,
      shopId: 'shop_a',
    );
    await u.execute();
    final ProductMasterUpdateEvent ev =
        transport.sent.single as ProductMasterUpdateEvent;
    expect(ev.productsJson, '[]');
  });
}
