import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/order_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, child: child)),
  );

  testWidgets('pending: 注文情報・アクションボタンを描画', (tester) async {
    int delivered = 0;
    int cancelled = 0;
    await tester.pumpWidget(
      host(
        OrderCard(
          ticketLabel: '042',
          status: OrderCardStatus.pending,
          lines: const <String>['中盛 × 2', 'おでん × 1'],
          totalText: '¥1,200',
          placedAtText: '12:34',
          onDeliver: () => delivered++,
          onCancel: () => cancelled++,
        ),
      ),
    );
    expect(find.text('042'), findsOneWidget);
    expect(find.text('提供前'), findsOneWidget);
    expect(find.text('中盛 × 2'), findsOneWidget);
    expect(find.text('¥1,200'), findsOneWidget);
    expect(find.text('12:34'), findsOneWidget);

    await tester.tap(find.text('提供完了'));
    await tester.pump();
    expect(delivered, 1);

    await tester.tap(find.text('キャンセル'));
    await tester.pump();
    expect(cancelled, 1);
  });

  testWidgets('delivered: 「提供済」バッジ、アクション非表示', (tester) async {
    await tester.pumpWidget(
      host(
        const OrderCard(
          ticketLabel: '01',
          status: OrderCardStatus.delivered,
          lines: <String>['湯豆腐 × 1'],
          totalText: '¥500',
        ),
      ),
    );
    expect(find.text('提供済'), findsOneWidget);
    expect(find.text('提供完了'), findsNothing);
    expect(find.text('キャンセル'), findsNothing);
  });

  testWidgets('cancelled: 「取消」バッジ', (tester) async {
    await tester.pumpWidget(
      host(
        const OrderCard(
          ticketLabel: '02',
          status: OrderCardStatus.cancelled,
          lines: <String>['x × 1'],
          totalText: '¥0',
        ),
      ),
    );
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('onTap が指定された場合 InkWell タップで発火', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      host(
        OrderCard(
          ticketLabel: '03',
          status: OrderCardStatus.delivered,
          lines: const <String>['a'],
          totalText: '¥0',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(taps, 1);
  });
}
