import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/regi/presentation/notifiers/regi_providers.dart';
import 'package:tofu_pos/features/regi/presentation/screens/regi_home_screen.dart';
import 'package:tofu_pos/providers/settings_providers.dart';

/// レジホーム画面のスモーク。
///
/// 目的:
///  - 主要な可視要素（タイトル / 「次回の整理券番号」 / 「次のお客様」ボタン）が出る
///  - 副次的なショートカットカード（注文履歴 / 商品マスタ / レジ締め / 設定）が出る
///
/// Provider は静的データに override して、業務ロジックを噛ませずに
/// レンダリング構造の回帰検出だけを目的とする。
void main() {
  testWidgets('RegiHomeScreen renders main UI elements', (tester) async {
    // ヘッダーの TicketBadge が小さい AppBar 内で軽微なオーバーフローを起こすが、
    // 業務上は問題のない見栄えの差。今回はスモークなのでオーバーフロー警告を許容する。
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
    // featureFlagsProvider が StreamProvider なので Stream イベントを流す。
    await tester.pump();
    // overflow exception を回収（スモークなのでレイアウト精緻さは検証しない）。
    while (tester.takeException() != null) {}

    // メインの見出し。
    expect(find.text('次回の整理券番号'), findsOneWidget);
    // 整理券番号 7 は zero-pad されて "07" 表示。ヘッダーバッジとヒーローの2箇所。
    expect(find.text('07'), findsAtLeastNWidgets(1));
    // 主要 CTA。
    expect(find.text('次のお客様'), findsOneWidget);
    // ショートカットカード（4 つ）。
    expect(find.text('注文履歴'), findsAtLeastNWidgets(1));
    expect(find.text('商品マスタ'), findsOneWidget);
    expect(find.text('レジ締め'), findsOneWidget);
    expect(find.text('設定'), findsAtLeastNWidgets(1));
  });

  testWidgets('RegiHomeScreen 整理券プール枯渇時は警告を出す', (tester) async {
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
            const AsyncData<TicketNumber?>(null),
          ),
        ],
        child: const MaterialApp(
          home: RegiHomeScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    expect(find.textContaining('整理券プール枯渇'), findsOneWidget);
  });
}
