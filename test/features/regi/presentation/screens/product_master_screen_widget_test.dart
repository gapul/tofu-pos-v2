import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/features/regi/presentation/notifiers/regi_providers.dart';
import 'package:tofu_pos/features/regi/presentation/screens/product_master_screen.dart';
import 'package:tofu_pos/providers/settings_providers.dart';

/// 商品マスタ画面のスモーク。
///
/// 空状態と 1 件描画の 2 ケース。
void main() {
  testWidgets('ProductMasterScreen 空状態は誘導 CTA を出す', (tester) async {
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
          activeProductsProvider.overrideWith(
            (ref) => Stream<List<Product>>.value(const <Product>[]),
          ),
        ],
        child: const MaterialApp(
          home: ProductMasterScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    expect(find.text('商品マスタ'), findsOneWidget);
    expect(find.text('商品が登録されていません'), findsOneWidget);
    expect(find.text('商品を追加'), findsOneWidget);
  });

  testWidgets('ProductMasterScreen 1 件を描画', (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const Product yudofu = Product(
      id: 'p1',
      name: '湯豆腐',
      price: Money(500),
      stock: 10,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            (ref) => Stream<FeatureFlags>.value(FeatureFlags.allOff),
          ),
          activeProductsProvider.overrideWith(
            (ref) => Stream<List<Product>>.value(<Product>[yudofu]),
          ),
        ],
        child: const MaterialApp(
          home: ProductMasterScreen(),
        ),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}

    expect(find.text('商品マスタ'), findsOneWidget);
    expect(find.text('湯豆腐'), findsOneWidget);
  });
}
