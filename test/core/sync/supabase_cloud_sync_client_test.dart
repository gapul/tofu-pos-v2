import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/sync/supabase_cloud_sync_client.dart';
import 'package:tofu_pos/domain/entities/customer_attributes.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/customer_attributes_enums.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

Order _makeOrder({
  Discount discount = Discount.none,
  OrderStatus status = OrderStatus.served,
}) {
  return Order(
    id: 42,
    ticketNumber: const TicketNumber(7),
    items: const <OrderItem>[
      OrderItem(
        productId: 'p1',
        productName: 'Yakisoba',
        priceAtTime: Money(400),
        quantity: 2,
      ),
      OrderItem(
        productId: 'p2',
        productName: 'Juice',
        priceAtTime: Money(150),
        quantity: 1,
      ),
    ],
    discount: discount,
    receivedCash: const Money(1000),
    createdAt: DateTime.utc(2026, 5, 7, 12, 30),
    orderStatus: status,
    syncStatus: SyncStatus.notSynced,
    customerAttributes: const CustomerAttributes(
      age: CustomerAge.twenties,
      gender: CustomerGender.female,
      group: CustomerGroup.solo,
    ),
  );
}

void main() {
  group('SupabaseCloudSyncClient.buildRows', () {
    test('produces one row per item', () {
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      expect(rows, hasLength(2));
    });

    test('all rows share order-level fields', () {
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      for (final Map<String, Object?> r in rows) {
        expect(r['shop_id'], 'shop_a');
        expect(r['local_order_id'], 42);
        expect(r['ticket_number'], 7);
        expect(r['order_status'], 'served');
        expect(r['is_cancelled'], false);
        expect(r['customer_age'], 'twenties');
        expect(r['customer_gender'], 'female');
        expect(r['customer_group'], 'solo');
      }
    });

    test('line_no is 1-based and sequential', () {
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      expect(rows[0]['line_no'], 1);
      expect(rows[1]['line_no'], 2);
    });

    test('discount is prorated by item subtotal share', () {
      // total = 400*2 + 150*1 = 950
      // -100円割引 → Yakisoba(800/950)*-100 ≒ -84, Juice(150/950)*-100 ≒ -16
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        _makeOrder(discount: const AmountDiscount(Money(-100))),
        shopId: 'shop_a',
      );
      expect(rows[0]['discount_per_item_yen'], -84);
      expect(rows[1]['discount_per_item_yen'], -16);
    });

    test('cancelled order sets is_cancelled and order_status', () {
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        _makeOrder(status: OrderStatus.cancelled),
        shopId: 'shop_a',
      );
      for (final Map<String, Object?> r in rows) {
        expect(r['order_status'], 'cancelled');
        expect(r['is_cancelled'], true);
      }
    });

    test('line-level fields copy item data', () {
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      expect(rows[0]['product_id'], 'p1');
      expect(rows[0]['product_name'], 'Yakisoba');
      expect(rows[0]['quantity'], 2);
      expect(rows[0]['price_at_time_yen'], 400);
      expect(rows[0]['total_item_price_yen'], 800);
    });

    test('createdAt is serialized as UTC ISO8601', () {
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      final String iso = rows[0]['order_created_at']! as String;
      expect(iso.endsWith('Z'), isTrue);
    });

    test('idempotency_key is present on every row', () {
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      for (final Map<String, Object?> r in rows) {
        expect(r['idempotency_key'], isA<String>());
        expect((r['idempotency_key']! as String).length, 36);
      }
    });

    test('idempotency_key is deterministic for same input', () {
      final List<Map<String, Object?>> a = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      final List<Map<String, Object?>> b = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      expect(a[0]['idempotency_key'], b[0]['idempotency_key']);
      expect(a[1]['idempotency_key'], b[1]['idempotency_key']);
    });

    test('idempotency_key differs across lines', () {
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      expect(rows[0]['idempotency_key'], isNot(rows[1]['idempotency_key']));
    });

    test('idempotency_key differs across shops', () {
      final List<Map<String, Object?>> a = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_a',
      );
      final List<Map<String, Object?>> b = SupabaseCloudSyncClient.buildRows(
        _makeOrder(),
        shopId: 'shop_b',
      );
      expect(a[0]['idempotency_key'], isNot(b[0]['idempotency_key']));
    });

    test('buildIdempotencyKey is pure and deterministic', () {
      final String k1 = SupabaseCloudSyncClient.buildIdempotencyKey(
        shopId: 'shop_a',
        orderId: 42,
        lineNo: 1,
      );
      final String k2 = SupabaseCloudSyncClient.buildIdempotencyKey(
        shopId: 'shop_a',
        orderId: 42,
        lineNo: 1,
      );
      expect(k1, k2);
      expect(k1, hasLength(36));
    });

    test('zero-total order produces zero discount per item', () {
      final Order order = Order(
        id: 1,
        ticketNumber: const TicketNumber(1),
        items: const <OrderItem>[
          OrderItem(
            productId: 'free',
            productName: 'Sample',
            priceAtTime: Money.zero,
            quantity: 1,
          ),
        ],
        discount: Discount.none,
        receivedCash: Money.zero,
        createdAt: DateTime.utc(2026, 5, 7),
        orderStatus: OrderStatus.served,
        syncStatus: SyncStatus.notSynced,
      );
      final List<Map<String, Object?>> rows = SupabaseCloudSyncClient.buildRows(
        order,
        shopId: 'shop_a',
      );
      expect(rows.single['discount_per_item_yen'], 0);
    });
  });
}
