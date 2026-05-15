import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/ui/app_header.dart';
import 'package:tofu_pos/domain/enums/transport_mode.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart' as vo;
import 'package:tofu_pos/providers/settings_providers.dart';
import 'package:tofu_pos/providers/sync_providers.dart';

/// AppHeader の単体 widget test。
///
/// portrait / landscape variant と、ticket / upcomingTicket / showStatus
/// の挙動を検証する。
void main() {
  Widget host({
    required Widget header,
    Size? physicalSize,
  }) {
    return ProviderScope(
      overrides: [
        transportModeProvider.overrideWith(
          (ref) => Stream<TransportMode>.value(TransportMode.online),
        ),
        syncWarningProvider.overrideWith(
          (ref) => Stream<SyncWarningLevel>.value(SyncWarningLevel.ok),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(appBar: header as PreferredSizeWidget, body: const SizedBox()),
      ),
    );
  }

  testWidgets('title を描画する（portrait variant）', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(header: const AppHeader(title: '会計')));
    await tester.pump();

    expect(find.text('会計'), findsOneWidget);
  });

  testWidgets('landscape 幅でも title が描画される', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(header: const AppHeader(title: 'キッチン')));
    await tester.pump();

    expect(find.text('キッチン'), findsOneWidget);
  });

  testWidgets('ticket が与えられると整理券番号が表示される', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        header: const AppHeader(
          title: 'レジ',
          ticket: vo.TicketNumber(12),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('整理券'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('upcomingTicket が与えられると次回番号として表示される', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        header: const AppHeader(
          title: 'レジ',
          upcomingTicket: vo.TicketNumber(8),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('次回'), findsOneWidget);
  });

  testWidgets('preferredSize は 89dp', (tester) async {
    const AppHeader header = AppHeader(title: 't');
    expect(header.preferredSize.height, 89);
  });
}
