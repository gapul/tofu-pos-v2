import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/status_indicator.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('6 つの type すべて既定ラベルを描画', (tester) async {
    final Map<StatusIndicatorType, String> expected =
        <StatusIndicatorType, String>{
          StatusIndicatorType.online: 'オンライン',
          StatusIndicatorType.offline: 'オフライン',
          StatusIndicatorType.bluetooth: 'Bluetooth',
          StatusIndicatorType.syncing: '同期中',
          StatusIndicatorType.synced: '同期済',
          StatusIndicatorType.syncError: '同期エラー',
        };
    for (final MapEntry<StatusIndicatorType, String> e in expected.entries) {
      await tester.pumpWidget(host(StatusIndicator(type: e.key)));
      expect(find.text(e.value), findsOneWidget);
    }
  });

  testWidgets('labelOverride で既定ラベルを差し替えられる', (tester) async {
    await tester.pumpWidget(
      host(
        const StatusIndicator(
          type: StatusIndicatorType.online,
          labelOverride: 'カスタム',
        ),
      ),
    );
    expect(find.text('カスタム'), findsOneWidget);
    expect(find.text('オンライン'), findsNothing);
  });

  testWidgets('custom コンストラクタはラベル / アイコン / tone を反映', (tester) async {
    await tester.pumpWidget(
      host(
        const StatusIndicator.custom(
          label: '注意',
          tone: StatusIndicatorTone.warning,
          icon: Icons.warning,
        ),
      ),
    );
    expect(find.text('注意'), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsOneWidget);
  });

  testWidgets('dense=true でも描画可能', (tester) async {
    await tester.pumpWidget(
      host(
        const StatusIndicator(type: StatusIndicatorType.online, dense: true),
      ),
    );
    expect(find.text('オンライン'), findsOneWidget);
  });
}
