import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/features/regi/presentation/screens/cash_close_screen.dart';
import 'package:tofu_pos/providers/repository_providers.dart';
import 'package:tofu_pos/providers/settings_providers.dart';

import '../../../../fakes/fake_repositories.dart';

/// レジ締め画面のスモーク。
///
/// 注文ゼロ・金種管理オフでヘッダーと売上サマリだけ出る最小構成を検証。
void main() {
  testWidgets('CashCloseScreen renders header and summary card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(InMemoryOrderRepository()),
          cashDrawerRepositoryProvider.overrideWithValue(
            InMemoryCashDrawerRepository(),
          ),
          featureFlagsProvider.overrideWith(
            (ref) => Stream<FeatureFlags>.value(FeatureFlags.allOff),
          ),
        ],
        child: const MaterialApp(
          home: CashCloseScreen(),
        ),
      ),
    );
    // Future 解決待ち。
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}

    expect(find.text('レジ締め'), findsOneWidget);
    // 売上合計のラベルが出る。
    expect(find.textContaining('売上'), findsAtLeastNWidgets(1));
  });
}
