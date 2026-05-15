import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/router/app_router.dart';
import 'package:tofu_pos/domain/enums/device_role.dart';
import 'package:tofu_pos/domain/value_objects/shop_id.dart';
import 'package:tofu_pos/features/startup/presentation/notifiers/setup_notifier.dart';

void main() {
  group('computeRedirect', () {
    const AsyncValue<SetupState> loading = AsyncLoading<SetupState>();
    const AsyncValue<SetupState> empty = AsyncData<SetupState>(
      SetupState.empty,
    );
    final AsyncValue<SetupState> shopOnly = AsyncData<SetupState>(
      SetupState(shopId: ShopId('yakisoba_A'), role: null),
    );
    final AsyncValue<SetupState> complete = AsyncData<SetupState>(
      SetupState(shopId: ShopId('yakisoba_A'), role: DeviceRole.register),
    );

    group('ロード中', () {
      test('どこに居てもリダイレクトしない（フリッカー防止）', () {
        expect(computeRedirect(loading, '/'), isNull);
        expect(computeRedirect(loading, '/setup/shop'), isNull);
        expect(computeRedirect(loading, '/regi/products'), isNull);
      });
    });

    group('未セットアップ（shop も role も無い）', () {
      test('業務ルートへの遷移は /setup/shop へ強制', () {
        expect(computeRedirect(empty, '/'), '/setup/shop');
        expect(computeRedirect(empty, '/regi/products'), '/setup/shop');
        expect(computeRedirect(empty, '/regi/checkout'), '/setup/shop');
        expect(computeRedirect(empty, '/settings'), '/setup/shop');
      });

      test('/setup/shop に居る場合はそのまま（ループ防止）', () {
        expect(computeRedirect(empty, '/setup/shop'), isNull);
      });

      test('shop 未設定で /setup/role に直接来た場合は /setup/shop へ戻す', () {
        expect(computeRedirect(empty, '/setup/role'), '/setup/shop');
      });
    });

    group('shopId のみ設定済み（role 未設定）', () {
      test('業務ルートは /setup/shop へ（実際は role 入力が必要だが、'
          '/setup/shop 経由で /setup/role に進ませる仕様）', () {
        expect(computeRedirect(shopOnly, '/'), '/setup/shop');
        expect(computeRedirect(shopOnly, '/regi/products'), '/setup/shop');
      });

      test('/setup/role に居る場合はそのまま進める（shopId 済みなので）', () {
        expect(computeRedirect(shopOnly, '/setup/role'), isNull);
      });

      test('/setup/shop に居る場合もそのまま', () {
        expect(computeRedirect(shopOnly, '/setup/shop'), isNull);
      });
    });

    group('セットアップ完了', () {
      test('業務ルートはそのまま通す', () {
        expect(computeRedirect(complete, '/'), isNull);
        expect(computeRedirect(complete, '/regi/products'), isNull);
        expect(computeRedirect(complete, '/regi/checkout'), isNull);
        expect(computeRedirect(complete, '/regi/history'), isNull);
        expect(computeRedirect(complete, '/regi/cash-close'), isNull);
        expect(computeRedirect(complete, '/settings'), isNull);
        expect(computeRedirect(complete, '/dev'), isNull);
      });

      test('/setup/* へ戻ろうとしたらホームへ追い返す', () {
        expect(computeRedirect(complete, '/setup/shop'), '/');
        expect(computeRedirect(complete, '/setup/role'), '/');
      });
    });

    group('役割別の挙動はホーム遷移後に決定する（このリダイレクト関数は役割を見ない）', () {
      test('register/kitchen/calling どれでも / は通す', () {
        for (final DeviceRole role in DeviceRole.values) {
          final AsyncValue<SetupState> s = AsyncData<SetupState>(
            SetupState(shopId: ShopId('shop'), role: role),
          );
          expect(
            computeRedirect(s, '/'),
            isNull,
            reason: 'role=$role のときに / はリダイレクト不要',
          );
        }
      });
    });

    group('AsyncError', () {
      final AsyncValue<SetupState> error = AsyncError<SetupState>(
        StateError('boom'),
        StackTrace.empty,
      );

      test('業務ルートからは /setup/shop へ戻す（安全側）', () {
        expect(computeRedirect(error, '/'), '/setup/shop');
        expect(computeRedirect(error, '/regi/products'), '/setup/shop');
      });

      test('/setup/* に居る場合はそのまま（ループ防止）', () {
        expect(computeRedirect(error, '/setup/shop'), isNull);
        expect(computeRedirect(error, '/setup/role'), isNull);
      });
    });
  });
}
