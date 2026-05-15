import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/tofu_checkbox.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('value=false でタップ → true、value=true でチェック表示', (tester) async {
    bool? received;
    await tester.pumpWidget(
      host(TofuCheckbox(value: false, onChanged: (v) => received = v)),
    );
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.byType(TofuCheckbox));
    await tester.pump();
    expect(received, isTrue);

    await tester.pumpWidget(
      host(TofuCheckbox(value: true, onChanged: (v) => received = v)),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('disabled (onChanged=null) は GestureDetector を持たない', (tester) async {
    await tester.pumpWidget(
      host(const TofuCheckbox(value: true, onChanged: null)),
    );
    expect(find.byType(GestureDetector), findsNothing);
  });
}
