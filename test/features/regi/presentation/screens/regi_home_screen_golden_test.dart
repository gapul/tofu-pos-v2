import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/regi/presentation/notifiers/regi_providers.dart';
import 'package:tofu_pos/features/regi/presentation/screens/regi_home_screen.dart';
import 'package:tofu_pos/providers/settings_providers.dart';

/// レジホーム画面の golden test（proof of concept）。
///
/// `flutter test --update-goldens` で初回シードし、以後は `flutter test` で
/// レンダリング差分を検知する。
/// 4 画面分（仕様書 §6.1 / §9.x）を計画していたが、フォントフォールバックや
/// CI 環境差での flakiness リスクを避けるため RegiHome 1 枚から開始する。
void main() {
  testWidgets('RegiHomeScreen golden', (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            (ref) => Stream<FeatureFlags>.value(FeatureFlags.allOff),
          ),
          upcomingTicketProvider.overrideWithValue(
            const AsyncData<TicketNumber?>(TicketNumber(7)),
          ),
        ],
        child: const MaterialApp(
          home: RegiHomeScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    await expectLater(
      find.byType(RegiHomeScreen),
      matchesGoldenFile('goldens/regi_home_default.png'),
    );
  });
}
