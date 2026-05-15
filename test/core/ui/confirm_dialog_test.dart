import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/confirm_dialog.dart';

void main() {
  testWidgets('standard: 確定ボタンを押すと true を返す', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await TofuConfirmDialog.show(
                    ctx,
                    title: '確認',
                    message: 'よろしいですか？',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('確認'), findsOneWidget);
    expect(find.text('よろしいですか？'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('standard: キャンセルを押すと false を返す', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await TofuConfirmDialog.show(
                    ctx,
                    title: '確認',
                    message: 'm',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('destructive: 警告アイコンと destructive 配置が出る', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => TofuConfirmDialog.show(
                  ctx,
                  title: '取消',
                  message: '本当に取り消しますか',
                  destructive: true,
                  confirmLabel: '取消する',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('取消する'), findsOneWidget);
  });
}
