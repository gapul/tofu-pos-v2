import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/kitchen_order.dart';
import 'package:tofu_pos/domain/enums/kitchen_status.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/kitchen/domain/kitchen_alert.dart';
import 'package:tofu_pos/features/kitchen/presentation/notifiers/kitchen_providers.dart';
import 'package:tofu_pos/features/kitchen/presentation/screens/kitchen_screen.dart';

/// キッチン画面の golden（仕様書 §6.2 / §9.4）。
void main() {
  testWidgets('KitchenScreen golden', tags: <String>['golden'], (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<KitchenOrder> orders = <KitchenOrder>[
      KitchenOrder(
        orderId: 1,
        ticketNumber: const TicketNumber(5),
        itemsJson: '[{"name":"湯豆腐","quantity":1}]',
        status: KitchenStatus.pending,
        receivedAt: DateTime(2026, 5, 8, 12),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kitchenOrdersProvider.overrideWith(
            (ref) => Stream<List<KitchenOrder>>.value(orders),
          ),
          kitchenAlertsProvider.overrideWith(
            (ref) => const Stream<KitchenAlert>.empty(),
          ),
        ],
        child: const MaterialApp(home: KitchenScreen()),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    await expectLater(
      find.byType(KitchenScreen),
      matchesGoldenFile('goldens/kitchen_default.png'),
    );
  });
}
