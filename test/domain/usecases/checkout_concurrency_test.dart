import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_ticket_pool_repository.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/usecases/checkout_usecase.dart';
import 'package:tofu_pos/domain/value_objects/checkout_draft.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';

import '../../fakes/fake_repositories.dart';

/// 並行に N 件 checkout した際の整理券番号がユニークであることを検証する。
///
/// CheckoutUseCase は UoW の **外** で `pool.allocate()` を呼ぶように改めた。
/// allocate は SharedPrefs Repository の内部ロックで直列化されるため、
/// 並列呼び出しでも `load -> issue -> save` がアトミックに走る。
void main() {
  group('CheckoutUseCase concurrent execute', () {
    test(
      '50 concurrent executes assign unique ticket numbers',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final SharedPrefsTicketPoolRepository poolRepo =
            SharedPrefsTicketPoolRepository(prefs, defaultMaxNumber: 200);

        final InMemoryProductRepository productRepo =
            InMemoryProductRepository(<Product>[
          const Product(
            id: 'p1',
            name: 'Yakisoba',
            price: Money(400),
            stock: 1000,
          ),
        ]);
        final InMemoryOrderRepository orderRepo = InMemoryOrderRepository();
        final InMemoryCashDrawerRepository cashRepo =
            InMemoryCashDrawerRepository();

        final CheckoutUseCase usecase = CheckoutUseCase(
          unitOfWork: InMemoryUnitOfWork(),
          orderRepository: orderRepo,
          productRepository: productRepo,
          cashDrawerRepository: cashRepo,
          ticketPoolRepository: poolRepo,
        );

        const CheckoutDraft draft = CheckoutDraft(
          items: <OrderItem>[
            OrderItem(
              productId: 'p1',
              productName: 'Yakisoba',
              priceAtTime: Money(400),
              quantity: 1,
            ),
          ],
          receivedCash: Money(500),
        );

        final List<Future<Order>> futures = <Future<Order>>[
          for (int i = 0; i < 50; i++)
            usecase.execute(draft: draft, flags: FeatureFlags.allOff),
        ];
        final List<Order> orders = await Future.wait(futures);

        expect(orders.length, 50);
        final Set<int> tickets =
            orders.map((o) => o.ticketNumber.value).toSet();
        expect(
          tickets.length,
          50,
          reason: '並行 checkout で整理券番号が重複している: '
              '${orders.map((o) => o.ticketNumber.value).toList()}',
        );
      },
    );
  });
}
