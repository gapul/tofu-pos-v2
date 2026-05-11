import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/regi/presentation/notifiers/regi_providers.dart';
import 'package:tofu_pos/features/regi/presentation/screens/product_select_screen.dart';
import 'package:tofu_pos/providers/settings_providers.dart';

/// 商品選択画面の golden（仕様書 §6.1.2 / §9.2）。
/// 初回は `flutter test --update-goldens` でシードする。
void main() {
  testWidgets('ProductSelectScreen golden', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<Product> products = <Product>[
      const Product(id: 'p1', name: '揚げ豆腐', price: Money(300), stock: 10),
      const Product(id: 'p2', name: '湯豆腐', price: Money(400), stock: 5),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            (ref) => Stream<FeatureFlags>.value(FeatureFlags.allOff),
          ),
          activeProductsProvider.overrideWith(
            (ref) => Stream<List<Product>>.value(products),
          ),
          upcomingTicketProvider.overrideWithValue(
            const AsyncData<TicketNumber?>(TicketNumber(3)),
          ),
        ],
        child: const MaterialApp(home: ProductSelectScreen()),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    await expectLater(
      find.byType(ProductSelectScreen),
      matchesGoldenFile('goldens/product_select_default.png'),
    );
  });
}
