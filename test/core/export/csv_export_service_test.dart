import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/export/csv_export_service.dart';
import 'package:tofu_pos/domain/entities/customer_attributes.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/customer_attributes_enums.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

void main() {
  const CsvExportService service = CsvExportService();

  Order makeOrder({
    int id = 1,
    int ticket = 7,
    Discount discount = Discount.none,
    OrderStatus status = OrderStatus.served,
  }) {
    return Order(
      id: id,
      ticketNumber: TicketNumber(ticket),
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
      syncStatus: SyncStatus.synced,
      customerAttributes: const CustomerAttributes(
        age: CustomerAge.twenties,
        gender: CustomerGender.female,
        group: CustomerGroup.solo,
      ),
    );
  }

  test('serializes header + one row per item', () {
    final String csv = service.serialize(
      orders: <Order>[makeOrder()],
      shopId: 'yakisoba_A',
    );
    final List<String> lines = csv.split('\r\n')..removeWhere((l) => l.isEmpty);
    expect(lines.first, startsWith('order_id,shop_id,'));
    // ヘッダ + 2明細行
    expect(lines.length, 3);
    expect(lines[1], contains('Yakisoba'));
    expect(lines[2], contains('Juice'));
  });

  test('per-item discount is prorated by subtotal share', () {
    // total = 400*2 + 150*1 = 950
    // -100円割引 → Yakisoba(800/950)*-100 ≒ -84, Juice(150/950)*-100 ≒ -16
    final String csv = service.serialize(
      orders: <Order>[makeOrder(discount: const AmountDiscount(Money(-100)))],
      shopId: 'shop',
    );
    final List<String> rows = csv
        .split('\r\n')
        .where((l) => l.isNotEmpty)
        .toList();
    final List<String> yakisobaCols = rows[1].split(',');
    final List<String> juiceCols = rows[2].split(',');
    final int yakisobaShare = int.parse(yakisobaCols[11]);
    final int juiceShare = int.parse(juiceCols[11]);
    expect(yakisobaShare, -84);
    expect(juiceShare, -16);
    // 按分の合計が元の割引額に近い（端数誤差±1）
    expect((yakisobaShare + juiceShare).abs(), inInclusiveRange(99, 101));
  });

  test('cancelled order is flagged', () {
    final String csv = service.serialize(
      orders: <Order>[makeOrder(status: OrderStatus.cancelled)],
      shopId: 'shop',
    );
    final List<String> rows = csv
        .split('\r\n')
        .where((l) => l.isNotEmpty)
        .toList();
    expect(rows[1], endsWith(',cancelled,true'));
  });

  test('embeds shopId on every row', () {
    final String csv = service.serialize(
      orders: <Order>[makeOrder(), makeOrder(id: 2, ticket: 8)],
      shopId: 'yakisoba_A',
    );
    final List<String> rows = csv
        .split('\r\n')
        .where((l) => l.isNotEmpty)
        .toList();
    for (int i = 1; i < rows.length; i++) {
      expect(rows[i].split(',')[1], 'yakisoba_A');
    }
  });
}
