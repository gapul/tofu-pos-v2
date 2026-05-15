import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/tofu_button.dart';

/// `TofuButton` の単体 widget test。variant × size × state を検証。
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('label と onPressed が動く（default primary md）', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      host(TofuButton(label: '会計確定', onPressed: () => taps++)),
    );
    expect(find.text('会計確定'), findsOneWidget);
    expect(find.byType(TofuButton), findsOneWidget);

    await tester.tap(find.byType(TofuButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('disabled (onPressed=null) はタップしてもコールバック発火しない', (tester) async {
    await tester.pumpWidget(
      host(const TofuButton(label: 'disabled', onPressed: null)),
    );
    final Finder btn = find.byType(TextButton);
    final TextButton w = tester.widget<TextButton>(btn);
    expect(w.onPressed, isNull);
  });

  testWidgets('loading=true は CircularProgressIndicator を表示しタップ無効化', (
    tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      host(TofuButton(label: 'submit', loading: true, onPressed: () => taps++)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // loading 時はラベル非表示。
    expect(find.text('submit'), findsNothing);

    await tester.tap(find.byType(TofuButton));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('icon を指定すると Icon が描画される', (tester) async {
    await tester.pumpWidget(
      host(TofuButton(label: '保存', icon: Icons.save, onPressed: () {})),
    );
    expect(find.byIcon(Icons.save), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('fullWidth=true で SizedBox(width: infinity) にラップされる', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 400,
          child: TofuButton(label: 'wide', fullWidth: true, onPressed: () {}),
        ),
      ),
    );
    final RenderBox box = tester.renderObject<RenderBox>(
      find.byType(TofuButton),
    );
    // 親 SizedBox=400 まで広がる。
    expect(box.size.width, greaterThanOrEqualTo(380));
  });

  testWidgets('size 軸（md/lg/xl）で minHeight が変わる', (tester) async {
    for (final TofuButtonSize s in TofuButtonSize.values) {
      await tester.pumpWidget(
        host(TofuButton(label: 'x', size: s, onPressed: () {})),
      );
      final Size size = tester.getSize(find.byType(TofuButton));
      final double expectedMin = switch (s) {
        TofuButtonSize.md => 56,
        TofuButtonSize.lg => 60,
        TofuButtonSize.xl => 68,
      };
      expect(size.height, greaterThanOrEqualTo(expectedMin));
    }
  });

  testWidgets('variant 軸（primary/secondary/danger/ghost）すべて描画できる', (
    tester,
  ) async {
    for (final TofuButtonVariant v in TofuButtonVariant.values) {
      await tester.pumpWidget(
        host(TofuButton(label: v.name, variant: v, onPressed: () {})),
      );
      expect(find.text(v.name), findsOneWidget);
    }
  });
}
