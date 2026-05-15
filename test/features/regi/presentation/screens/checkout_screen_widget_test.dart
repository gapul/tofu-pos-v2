import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/regi/presentation/notifiers/checkout_session.dart';
import 'package:tofu_pos/features/regi/presentation/notifiers/regi_providers.dart';
import 'package:tofu_pos/features/regi/presentation/screens/checkout_screen.dart';
import 'package:tofu_pos/providers/settings_providers.dart';

/// 会計画面のスモーク（仕様書 §6.1.3 / §9.3）。
///
/// 目的:
///  - タイトル・合計欄が描画されること
///  - 注文内容に session の商品が反映されること
///
/// 業務ロジック（FlowUseCase）には触れないので、
/// 画面のレンダリング構造の回帰検出だけを目的とする。
class _StubCheckoutNotifier extends CheckoutSessionNotifier {
  _StubCheckoutNotifier(this._initial);
  final CheckoutSession _initial;

  @override
  CheckoutSession build() => _initial;
}

void main() {
  testWidgets('CheckoutScreen タイトルと注文内容が描画される', (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final CheckoutSession seeded = CheckoutSession.empty().copyWith(
      items: <OrderItem>[
        const OrderItem(
          productId: 'p1',
          productName: '湯豆腐',
          priceAtTime: Money(500),
          quantity: 2,
        ),
      ],
      receivedCash: const Money(2000),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            (ref) => Stream<FeatureFlags>.value(FeatureFlags.allOff),
          ),
          upcomingTicketProvider.overrideWithValue(
            const AsyncData<TicketNumber?>(TicketNumber(7)),
          ),
          checkoutSessionProvider.overrideWith(
            () => _StubCheckoutNotifier(seeded),
          ),
        ],
        child: const MaterialApp(
          home: CheckoutScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    // AppHeader はブランド固定「レジ」、画面固有タイトルは PageTitle で「お会計」。
    expect(find.text('レジ'), findsOneWidget);
    expect(find.text('お会計'), findsOneWidget);
    // Figma 70:88 サマリーカード: 商品行 + 小計 / 請求金額。
    expect(find.text('湯豆腐'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('小計'), findsAtLeastNWidgets(1));
    expect(find.text('請求金額'), findsAtLeastNWidgets(1));
  });
}
