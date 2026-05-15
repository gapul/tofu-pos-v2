import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/pane_title.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('title が描画される（最小構成）', (tester) async {
    await tester.pumpWidget(host(const PaneTitle(title: '未調理')));
    expect(find.text('未調理'), findsOneWidget);
    expect(find.textContaining('件'), findsNothing);
  });

  testWidgets('count を指定すると件数バッジが描画される', (tester) async {
    await tester.pumpWidget(host(const PaneTitle(title: '未調理', count: 3)));
    expect(find.text('3件'), findsOneWidget);
  });

  testWidgets('subtitle / trailing が描画される', (tester) async {
    await tester.pumpWidget(
      host(
        const PaneTitle(
          title: 'タイトル',
          subtitle: '直近 50 件',
          trailing: Icon(Icons.more_horiz, key: ValueKey('trailing')),
        ),
      ),
    );
    expect(find.text('直近 50 件'), findsOneWidget);
    expect(find.byKey(const ValueKey('trailing')), findsOneWidget);
  });
}
