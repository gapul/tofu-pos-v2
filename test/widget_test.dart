import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tofu_pos/app.dart';
import 'package:tofu_pos/providers/database_providers.dart';

void main() {
  testWidgets('App boots and shows placeholder home', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const TofuPosApp(),
      ),
    );

    expect(find.text('Tofu POS'), findsOneWidget);
    expect(find.text('セットアップ中（Phase 0 完了）'), findsOneWidget);
  });
}
