import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/calling_order.dart';
import 'package:tofu_pos/domain/enums/calling_status.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/calling/presentation/notifiers/calling_providers.dart';
import 'package:tofu_pos/features/calling/presentation/screens/calling_screen.dart';

/// 呼び出し画面のスモーク。
///
/// 2 ペイン（呼び出し前 / 呼び出し済み）の見出しと、1 件の整理券番号が
/// 描画されることを確認するだけ。
void main() {
  testWidgets('CallingScreen renders header and two columns', (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final CallingOrder pending = CallingOrder(
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      status: CallingStatus.pending,
      receivedAt: DateTime(2026, 5, 11, 12),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          callingOrdersProvider.overrideWith(
            (ref) =>
                Stream<List<CallingOrder>>.value(<CallingOrder>[pending]),
          ),
        ],
        child: const MaterialApp(
          home: CallingScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    // AppHeader title
    expect(find.text('呼び出し'), findsOneWidget);
    // 2 ペイン見出し（新 UI では「呼び出し済み」→「呼び出し済」に短縮）
    expect(find.text('呼び出し前'), findsOneWidget);
    expect(find.text('呼び出し済'), findsOneWidget);
    // 整理券番号 7 は "07" として描画される。
    expect(find.textContaining('07'), findsAtLeastNWidgets(1));
  });
}
