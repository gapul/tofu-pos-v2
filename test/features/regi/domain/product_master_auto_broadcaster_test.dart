import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/noop_transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/features/regi/domain/product_master_auto_broadcaster.dart';
import 'package:tofu_pos/features/regi/domain/product_master_broadcast_usecase.dart';

import '../../../fakes/fake_repositories.dart';

void main() {
  test('debounces multiple rapid changes into one broadcast', () async {
    final repo = InMemoryProductRepository(<Product>[]);
    final transport = NoopTransport();
    final broadcastUseCase = ProductMasterBroadcastUseCase(
      productRepository: repo,
      transport: transport,
      shopId: 'shop_a',
    );
    final auto = ProductMasterAutoBroadcaster(
      productRepository: repo,
      broadcast: broadcastUseCase,
      debounce: const Duration(milliseconds: 50),
      periodicInterval: const Duration(hours: 1),
    );
    auto.start();

    // 連続編集
    await repo.upsert(
      const Product(id: 'a', name: 'A', price: Money(100), stock: 1),
    );
    await repo.upsert(
      const Product(id: 'b', name: 'B', price: Money(100), stock: 1),
    );
    await repo.upsert(
      const Product(id: 'c', name: 'C', price: Money(100), stock: 1),
    );

    // debounce 経過まで待つ
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(transport.sent.length, 1, reason: '3回連続編集が debounce で1回にまとまる');
    expect(transport.sent.single, isA<ProductMasterUpdateEvent>());

    await auto.stop();
  });

  test('periodic timer triggers broadcast even without changes', () async {
    final repo = InMemoryProductRepository(<Product>[
      const Product(id: 'a', name: 'A', price: Money(100), stock: 1),
    ]);
    final transport = NoopTransport();
    final broadcastUseCase = ProductMasterBroadcastUseCase(
      productRepository: repo,
      transport: transport,
      shopId: 'shop_a',
    );
    final auto = ProductMasterAutoBroadcaster(
      productRepository: repo,
      broadcast: broadcastUseCase,
      debounce: const Duration(seconds: 1),
      periodicInterval: const Duration(milliseconds: 100),
    );
    auto.start();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await auto.stop();
    expect(transport.sent.length, greaterThanOrEqualTo(2));
  });

  test('stop cancels timers and stream listening', () async {
    final repo = InMemoryProductRepository(<Product>[]);
    final transport = NoopTransport();
    final broadcastUseCase = ProductMasterBroadcastUseCase(
      productRepository: repo,
      transport: transport,
      shopId: 'shop_a',
    );
    final auto = ProductMasterAutoBroadcaster(
      productRepository: repo,
      broadcast: broadcastUseCase,
      debounce: const Duration(milliseconds: 50),
      periodicInterval: const Duration(milliseconds: 50),
    );
    auto.start();
    expect(auto.isStarted, isTrue);
    await auto.stop();
    expect(auto.isStarted, isFalse);

    // stop 後の編集はトリガーされない
    await repo.upsert(
      const Product(id: 'x', name: 'X', price: Money(100), stock: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(transport.sent, isEmpty);
  });
}
