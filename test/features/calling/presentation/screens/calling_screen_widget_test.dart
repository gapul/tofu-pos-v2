import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tofu_pos/domain/entities/calling_order.dart';
import 'package:tofu_pos/domain/enums/calling_status.dart';
import 'package:tofu_pos/domain/repositories/calling_order_repository.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/calling/presentation/notifiers/calling_providers.dart';
import 'package:tofu_pos/features/calling/presentation/screens/calling_screen.dart';
import 'package:tofu_pos/providers/repository_providers.dart';

class _MockCallingOrderRepository extends Mock
    implements CallingOrderRepository {}

/// 呼び出し画面のスモーク。
///
/// 2 ペイン（呼び出し前 / 呼び出し済み）の見出しと、1 件の整理券番号が
/// 描画されることを確認するだけ。
void main() {
  setUpAll(() {
    registerFallbackValue(CallingStatus.pending);
  });

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
            (ref) => Stream<List<CallingOrder>>.value(<CallingOrder>[pending]),
          ),
        ],
        child: const MaterialApp(
          home: CallingScreen(),
        ),
      ),
    );
    await tester.pump();
    // flutter_animate のリスト追加トランジション (PR-3) を完全消化する。
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}

    // AppHeader (brand) と body の PageTitle で 2 箇所に出る。
    expect(find.text('呼び出し'), findsNWidgets(2));
    // 2 ペイン見出し（新 UI では「呼び出し済み」→「呼び出し済」に短縮）
    expect(find.text('呼び出し前'), findsOneWidget);
    expect(find.text('呼び出し済'), findsOneWidget);
    // 整理券番号 7 は "07" として描画される。
    expect(find.textContaining('07'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'pending カードを tap → fullscreen dialog 表示 → 閉じると updateStatus(called)',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final _MockCallingOrderRepository repo = _MockCallingOrderRepository();
      when(() => repo.updateStatus(any(), any())).thenAnswer((_) async {});

      final CallingOrder pending = CallingOrder(
        orderId: 42,
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
            callingOrderRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: CallingScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      // 「呼び出し前」ペインの大型カードをタップ。
      await tester.tap(find.text('07').first);
      await tester.pumpAndSettle();

      // フルスクリーンダイアログの「お呼び出し」が出る。
      expect(find.text('お呼び出し'), findsOneWidget);
      expect(find.text('お受け取りください'), findsOneWidget);

      // 右下「呼び出し済み」ボタン押下で markCalled される。
      await tester.tap(find.text('呼び出し済み'));
      await tester.pumpAndSettle();

      // ダイアログが閉じている。
      expect(find.text('お呼び出し'), findsNothing);
      // updateStatus(orderId=42, called) が呼ばれている。
      verify(() => repo.updateStatus(42, CallingStatus.called)).called(1);
    },
  );
}
