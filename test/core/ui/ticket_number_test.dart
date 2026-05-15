import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/ticket_number.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('number を描画する（default md）', (tester) async {
    await tester.pumpWidget(host(const TicketNumber(number: '042')));
    expect(find.text('042'), findsOneWidget);
  });

  testWidgets('label を指定すると上段に出る', (tester) async {
    await tester.pumpWidget(
      host(const TicketNumber(number: '07', label: '整理券')),
    );
    expect(find.text('07'), findsOneWidget);
    expect(find.text('整理券'), findsOneWidget);
  });

  testWidgets('5 つの size すべて描画できる', (tester) async {
    for (final TicketNumberSize s in TicketNumberSize.values) {
      await tester.pumpWidget(
        host(TicketNumber(number: '01', size: s, label: s.name)),
      );
      expect(find.text('01'), findsOneWidget);
      expect(find.text(s.name), findsOneWidget);
    }
  });

  testWidgets('emphasized=false でも描画できる', (tester) async {
    await tester.pumpWidget(
      host(const TicketNumber(number: '99', emphasized: false)),
    );
    expect(find.text('99'), findsOneWidget);
  });
}
