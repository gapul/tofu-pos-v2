import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/usecases/hourly_sales_usecase.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/hourly_sales_bucket.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

import '../../fakes/fake_repositories.dart';

Order _o({
  required int id,
  required DateTime at,
  Money price = const Money(500),
  OrderStatus status = OrderStatus.served,
}) {
  return Order(
    id: id,
    ticketNumber: TicketNumber(id),
    items: <OrderItem>[
      OrderItem(
        productId: 'p',
        productName: 'P',
        priceAtTime: price,
        quantity: 1,
      ),
    ],
    discount: Discount.none,
    receivedCash: price,
    createdAt: at,
    orderStatus: status,
    syncStatus: SyncStatus.synced,
  );
}

void main() {
  late InMemoryOrderRepository orderRepo;
  late HourlySalesUseCase usecase;

  setUp(() {
    orderRepo = InMemoryOrderRepository();
    usecase = HourlySalesUseCase(
      orderRepository: orderRepo,
      now: () => DateTime(2026, 5, 7, 18),
    );
  });

  test('returns 24 buckets', () async {
    final List<HourlySalesBucket> r = await usecase.getHourly();
    expect(r, hasLength(24));
    for (int h = 0; h < 24; h++) {
      expect(r[h].hour, h);
      expect(r[h].orderCount, 0);
      expect(r[h].totalSales, Money.zero);
    }
  });

  test('aggregates orders into correct buckets', () async {
    await orderRepo.create(_o(id: 1, at: DateTime(2026, 5, 7, 10, 30)));
    await orderRepo.create(_o(id: 2, at: DateTime(2026, 5, 7, 10, 45)));
    await orderRepo.create(_o(id: 3, at: DateTime(2026, 5, 7, 14, 15)));

    final List<HourlySalesBucket> r = await usecase.getHourly();
    expect(r[10].orderCount, 2);
    expect(r[10].totalSales, const Money(1000));
    expect(r[14].orderCount, 1);
    expect(r[14].totalSales, const Money(500));
    expect(r[11].orderCount, 0);
  });

  test('cancelled orders are excluded', () async {
    await orderRepo.create(_o(id: 1, at: DateTime(2026, 5, 7, 10)));
    await orderRepo.create(
      _o(
        id: 2,
        at: DateTime(2026, 5, 7, 10, 30),
        status: OrderStatus.cancelled,
      ),
    );

    final List<HourlySalesBucket> r = await usecase.getHourly();
    expect(r[10].orderCount, 1);
    expect(r[10].totalSales, const Money(500));
  });

  test('orders outside the day are excluded', () async {
    await orderRepo.create(_o(id: 1, at: DateTime(2026, 5, 6, 10)));
    await orderRepo.create(_o(id: 2, at: DateTime(2026, 5, 8, 10)));
    await orderRepo.create(_o(id: 3, at: DateTime(2026, 5, 7, 10)));

    final List<HourlySalesBucket> r = await usecase.getHourly();
    final int totalForDay = r.fold(
      0,
      (sum, b) => sum + b.orderCount,
    );
    expect(totalForDay, 1);
  });

  test('getActiveHourly returns only buckets with orders', () async {
    await orderRepo.create(_o(id: 1, at: DateTime(2026, 5, 7, 10)));
    await orderRepo.create(_o(id: 2, at: DateTime(2026, 5, 7, 14)));

    final List<HourlySalesBucket> r = await usecase.getActiveHourly();
    expect(r.map((b) => b.hour), <int>[10, 14]);
  });
}
