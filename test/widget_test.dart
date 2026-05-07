import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tofu_pos/app.dart';

void main() {
  testWidgets('App boots and shows placeholder home', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TofuPosApp()),
    );

    expect(find.text('Tofu POS'), findsOneWidget);
    expect(find.text('セットアップ中（Phase 0 完了）'), findsOneWidget);
  });
}
