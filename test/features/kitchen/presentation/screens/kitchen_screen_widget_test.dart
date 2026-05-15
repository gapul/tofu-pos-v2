import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/alert_banner.dart';
import 'package:tofu_pos/domain/entities/kitchen_order.dart';
import 'package:tofu_pos/domain/enums/kitchen_status.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/kitchen/domain/kitchen_alert.dart';
import 'package:tofu_pos/features/kitchen/presentation/notifiers/kitchen_providers.dart';
import 'package:tofu_pos/features/kitchen/presentation/screens/kitchen_screen.dart';

/// キッチン画面のスモーク（仕様書 §6.2 / §9.4）。
void main() {
  testWidgets('KitchenScreen タブ・タイトル・空状態が出る', (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kitchenOrdersProvider.overrideWith(
            (ref) => Stream<List<KitchenOrder>>.value(<KitchenOrder>[]),
          ),
          // alerts は emit しない空ストリームに差し替え。
          kitchenAlertsProvider.overrideWith(
            (ref) => const Stream<KitchenAlert>.empty(),
          ),
        ],
        child: const MaterialApp(
          home: KitchenScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    // AppHeader (brand) と body の PageTitle で 2 箇所に出る。
    expect(find.text('キッチン'), findsNWidgets(2));
    // 新 UI では「未調理」「提供済」をペイン見出し + タブ見出しで併用する。
    // 件数付き Tab ラベル（"未調理 (0)") と PaneTitle "未調理" の両方が描画される。
    expect(find.text('未調理'), findsAtLeastNWidgets(1));
    expect(find.text('提供済'), findsAtLeastNWidgets(1));
    expect(find.text('未調理の注文はありません'), findsOneWidget);
  });

  testWidgets('KitchenScreen 受信済の注文を一覧表示', (tester) async {
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
        child: const MaterialApp(
          home: KitchenScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    // 整理券番号が表示される。
    expect(find.textContaining('05'), findsAtLeastNWidgets(1));
  });

  testWidgets('kitchenAlertsProvider が KitchenAlert を emit すると AlertBanner(danger) を描画',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final KitchenAlert alert = KitchenAlert.cancelledMidProcess(
      orderId: 99,
      ticketNumber: const TicketNumber(13),
      previousStatus: KitchenStatus.done,
    );

    // 通知が postFrameCallback で listenManual される設計なので、
    // 値をすぐ流すために単発の Stream.value を渡す。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kitchenOrdersProvider.overrideWith(
            (ref) => Stream<List<KitchenOrder>>.value(<KitchenOrder>[]),
          ),
          kitchenAlertsProvider.overrideWith(
            (ref) => Stream<KitchenAlert>.value(alert),
          ),
        ],
        child: const MaterialApp(home: KitchenScreen()),
      ),
    );
    // initState → postFrameCallback → listenManual → stream emit。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    while (tester.takeException() != null) {}

    // AlertBanner（danger）が描画されている。
    expect(find.byType(AlertBanner), findsOneWidget);
    expect(find.textContaining('注文取消'), findsOneWidget);
    expect(find.textContaining('整理券 13'), findsOneWidget);

    // 「了解」ボタンを押すと AlertBanner が消える。
    await tester.tap(find.text('了解'));
    await tester.pump();
    expect(find.byType(AlertBanner), findsNothing);
  });
}
