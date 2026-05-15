import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/tofu_toggle.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('value=false でタップ → onChanged(true)', (tester) async {
    bool? received;
    await tester.pumpWidget(
      host(TofuToggle(value: false, onChanged: (v) => received = v)),
    );
    await tester.tap(find.byType(TofuToggle));
    await tester.pump();
    expect(received, isTrue);
  });

  testWidgets('value=true でタップ → onChanged(false)', (tester) async {
    bool? received;
    await tester.pumpWidget(
      host(TofuToggle(value: true, onChanged: (v) => received = v)),
    );
    await tester.tap(find.byType(TofuToggle));
    await tester.pump();
    expect(received, isFalse);
  });

  testWidgets('onChanged=null（disabled）はタップで何も起こらない', (tester) async {
    await tester.pumpWidget(
      host(const TofuToggle(value: true, onChanged: null)),
    );
    // GestureDetector が無い（disabled パス）= タップしても発火しない。
    expect(find.byType(GestureDetector), findsNothing);
  });
}
