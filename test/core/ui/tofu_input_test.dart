import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/tofu_input.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );

  testWidgets('hintText が描画される（default state）', (tester) async {
    await tester.pumpWidget(host(const TofuInput(hintText: 'バーコードを入力')));
    expect(find.text('バーコードを入力'), findsOneWidget);
  });

  testWidgets('onChanged が文字入力で発火する', (tester) async {
    final List<String> events = <String>[];
    await tester.pumpWidget(host(TofuInput(onChanged: events.add)));
    await tester.enterText(find.byType(TextField), 'abc');
    expect(events, <String>['abc']);
  });

  testWidgets('errorText 指定時に error 文言が描画される', (tester) async {
    await tester.pumpWidget(
      host(const TofuInput(errorText: '不正な値です')),
    );
    expect(find.text('不正な値です'), findsOneWidget);
  });

  testWidgets('enabled=false で TextField.enabled が false', (tester) async {
    await tester.pumpWidget(host(const TofuInput(enabled: false)));
    final TextField tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.enabled, isFalse);
  });

  testWidgets('size=lg で最小高さ 60dp 以上', (tester) async {
    await tester.pumpWidget(host(const TofuInput(size: TofuInputSize.lg)));
    final Size size = tester.getSize(find.byType(TofuInput));
    expect(size.height, greaterThanOrEqualTo(60));
  });
}
