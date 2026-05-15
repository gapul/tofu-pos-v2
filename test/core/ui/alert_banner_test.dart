import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/alert_banner.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: SizedBox(width: 600, child: child)));

  testWidgets('title と message を描画する', (tester) async {
    await tester.pumpWidget(
      host(const AlertBanner(title: '注意', message: '在庫がありません')),
    );
    expect(find.text('注意'), findsOneWidget);
    expect(find.text('在庫がありません'), findsOneWidget);
  });

  testWidgets('4 variant すべてレンダリングできる', (tester) async {
    for (final AlertBannerVariant v in AlertBannerVariant.values) {
      await tester.pumpWidget(host(AlertBanner(variant: v, message: v.name)));
      expect(find.text(v.name), findsOneWidget);
    }
  });

  testWidgets('actionLabel + onAction が動作', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      host(
        AlertBanner(
          message: 'メッセージ',
          actionLabel: '再試行',
          onAction: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('再試行'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('onClose を指定すると閉じる × ボタンが出てタップで発火', (tester) async {
    int closed = 0;
    await tester.pumpWidget(
      host(
        AlertBanner(
          message: 'm',
          onClose: () => closed++,
        ),
      ),
    );
    final Finder closeBtn = find.byTooltip('閉じる');
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pump();
    expect(closed, 1);
  });
}
