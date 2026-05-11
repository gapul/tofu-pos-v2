import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/regi/presentation/notifiers/regi_providers.dart';
import 'package:tofu_pos/features/regi/presentation/screens/order_history_screen.dart';
import 'package:tofu_pos/providers/settings_providers.dart';

/// 注文履歴画面のスモーク。
///
/// 空状態と1件あるパターンの 2 ケースで描画構造の回帰を防ぐ。
void main() {
  testWidgets('OrderHistoryScreen 注文が無い時は空メッセージ', (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            (ref) => Stream<FeatureFlags>.value(FeatureFlags.allOff),
          ),
          orderHistoryProvider.overrideWith(
            (ref) => Stream<List<Order>>.value(const <Order>[]),
          ),
        ],
        child: const MaterialApp(
          home: OrderHistoryScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    expect(find.text('注文履歴'), findsOneWidget);
    expect(find.text('注文はまだありません'), findsOneWidget);
  });

  testWidgets('OrderHistoryScreen 注文 1 件を描画', (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Order order = Order(
      id: 1,
      ticketNumber: const TicketNumber(7),
      items: const <OrderItem>[
        OrderItem(
          productId: 'p1',
          productName: '湯豆腐',
          priceAtTime: Money(500),
          quantity: 1,
        ),
      ],
      discount: Discount.none,
      receivedCash: const Money(1000),
      createdAt: DateTime(2026, 5, 11, 12),
      orderStatus: OrderStatus.served,
      syncStatus: SyncStatus.synced,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            (ref) => Stream<FeatureFlags>.value(FeatureFlags.allOff),
          ),
          orderHistoryProvider.overrideWith(
            (ref) => Stream<List<Order>>.value(<Order>[order]),
          ),
        ],
        child: const MaterialApp(
          home: OrderHistoryScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    expect(find.text('注文履歴'), findsOneWidget);
    // 整理券番号 7 は "07" として描画される。
    expect(find.textContaining('07'), findsAtLeastNWidgets(1));
  });
}
