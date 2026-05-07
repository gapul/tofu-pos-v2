import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tofu_pos/core/export/csv_export_file_service.dart';
import 'package:tofu_pos/domain/entities/customer_attributes.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

Order _order() {
  return Order(
    id: 1,
    ticketNumber: const TicketNumber(7),
    items: const <OrderItem>[
      OrderItem(
        productId: 'p1',
        productName: 'Yakisoba',
        priceAtTime: Money(400),
        quantity: 1,
      ),
    ],
    discount: Discount.none,
    receivedCash: const Money(400),
    createdAt: DateTime.utc(2026, 5, 7, 12),
    orderStatus: OrderStatus.served,
    syncStatus: SyncStatus.synced,
    customerAttributes: CustomerAttributes.empty,
  );
}

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('tofu_pos_csv_test_');
  });

  tearDown(() async {
    if (tmpDir.existsSync()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('writeToFile produces a CSV in the given directory', () async {
    final CsvExportFileService svc = CsvExportFileService(
      getDirectory: () async => tmpDir,
      now: () => DateTime(2026, 5, 7, 18, 30),
    );

    final String path = await svc.writeToFile(
      orders: <Order>[_order()],
      shopId: 'yakisoba_A',
    );

    final File f = File(path);
    expect(f.existsSync(), isTrue);
    final String body = await f.readAsString();
    expect(body, startsWith('order_id,shop_id,'));
    expect(body, contains('Yakisoba'));
    expect(path, endsWith('.csv'));
    expect(path, contains('yakisoba_A'));
    expect(path, contains('20260507_1830'));
  });

  test('shopId with special chars is sanitized in filename', () async {
    final CsvExportFileService svc = CsvExportFileService(
      getDirectory: () async => tmpDir,
      now: () => DateTime(2026, 5, 7, 9, 5),
    );
    final String path = await svc.writeToFile(
      orders: <Order>[_order()],
      shopId: 'shop/with spaces!',
    );
    expect(path, contains('shop_with_spaces_'));
    expect(path, isNot(contains('/with')));
  });

  test('writeAndShare writes file and invokes share sheet', () async {
    bool shareCalled = false;
    String? sharedPath;
    String? sharedSubject;
    final CsvExportFileService svc = CsvExportFileService(
      getDirectory: () async => tmpDir,
      now: () => DateTime(2026, 5, 7),
      share: (List<XFile> files, {String? subject}) async {
        shareCalled = true;
        sharedPath = files.single.path;
        sharedSubject = subject;
        return const ShareResult('ok', ShareResultStatus.success);
      },
    );

    final String path = await svc.writeAndShare(
      orders: <Order>[_order()],
      shopId: 'shop',
    );

    expect(shareCalled, isTrue);
    expect(sharedPath, path);
    expect(sharedSubject, 'Tofu POS 売上データ');
    expect(File(path).existsSync(), isTrue);
  });
}
