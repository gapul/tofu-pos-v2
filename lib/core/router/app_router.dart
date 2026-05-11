import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/order.dart';
import '../../domain/enums/device_role.dart';
import '../../features/calling/presentation/screens/calling_screen.dart';
import '../../features/dev_console/presentation/screens/dev_console_screen.dart';
import '../../features/kitchen/presentation/screens/kitchen_screen.dart';
import '../../features/regi/presentation/screens/cash_close_screen.dart';
import '../../features/regi/presentation/screens/checkout_done_screen.dart';
import '../../features/regi/presentation/screens/checkout_screen.dart';
import '../../features/regi/presentation/screens/customer_attributes_screen.dart';
import '../../features/regi/presentation/screens/order_history_screen.dart';
import '../../features/regi/presentation/screens/product_master_screen.dart';
import '../../features/regi/presentation/screens/product_select_screen.dart';
import '../../features/regi/presentation/screens/regi_home_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/startup/presentation/notifiers/setup_notifier.dart';
import '../../features/startup/presentation/screens/role_select_screen.dart';
import '../../features/startup/presentation/screens/shop_id_screen.dart';
import '../theme/tokens.dart';
import '../ui/error_boundary.dart';

/// セットアップ状態と現在地から、リダイレクト先パス（不要なら null）を返す。
///
/// GoRouter の redirect コールバックの中身を純関数として切り出したもの。
/// 単体テストで網羅的に検証できるようにし、redirect 自体は薄く保つ。
///
/// [setup] が `AsyncLoading` の場合はリダイレクトを抑止して null を返す
/// （フリッカー防止）。`AsyncError` の場合は安全側に倒し、業務ルートからは
/// `/setup/shop` へ戻す。
@visibleForTesting
String? computeRedirect(AsyncValue<SetupState> setup, String location) {
  final bool isSetupRoute = location.startsWith('/setup');

  return setup.when(
    loading: () => null,
    error: (_, _) => isSetupRoute ? null : '/setup/shop',
    data: (data) {
      if (!data.isComplete) {
        if (location == '/setup/role' && data.shopId == null) {
          return '/setup/shop';
        }
        return isSetupRoute ? null : '/setup/shop';
      }
      // 設定済み: setup ルートはホームへリダイレクト
      if (isSetupRoute) {
        return '/';
      }
      return null;
    },
  );
}

/// アプリ全体のルーティング定義（仕様書 §3）。
///
/// セットアップが未完了なら /setup/* へ強制遷移、完了済みなら役割別ホームへ。
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((
  ref,
) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) =>
        computeRedirect(ref.read(setupNotifierProvider), state.matchedLocation),
    refreshListenable: _SetupChangeNotifier(ref),
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (c, s) => const ErrorBoundary(
          label: 'route:/',
          child: _HomeRouter(),
        ),
      ),
      // /setup/* は意図的に ErrorBoundary を被せない。
      // 失敗したら原因が見えるよう loud に落ちて欲しい初期化フロー。
      GoRoute(
        path: '/setup/shop',
        builder: (c, s) => const ShopIdScreen(),
      ),
      GoRoute(
        path: '/setup/role',
        builder: (c, s) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: '/regi/customer',
        builder: (c, s) => const ErrorBoundary(
          label: 'route:/regi/customer',
          child: CustomerAttributesScreen(),
        ),
      ),
      GoRoute(
        path: '/regi/products',
        builder: (c, s) => const ErrorBoundary(
          label: 'route:/regi/products',
          child: ProductSelectScreen(),
        ),
      ),
      GoRoute(
        path: '/regi/products/master',
        builder: (c, s) => const ErrorBoundary(
          label: 'route:/regi/products/master',
          child: ProductMasterScreen(),
        ),
      ),
      GoRoute(
        path: '/regi/checkout',
        builder: (c, s) => const ErrorBoundary(
          label: 'route:/regi/checkout',
          child: CheckoutScreen(),
        ),
      ),
      GoRoute(
        path: '/regi/done',
        builder: (c, s) {
          final Object? extra = s.extra;
          if (extra is Order) {
            return ErrorBoundary(
              label: 'route:/regi/done',
              child: CheckoutDoneScreen(order: extra),
            );
          }
          return const _MissingOrderRedirect();
        },
      ),
      GoRoute(
        path: '/regi/history',
        builder: (c, s) => const ErrorBoundary(
          label: 'route:/regi/history',
          child: OrderHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/regi/cash-close',
        builder: (c, s) => const ErrorBoundary(
          label: 'route:/regi/cash-close',
          child: CashCloseScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (c, s) => const ErrorBoundary(
          label: 'route:/settings',
          child: SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/dev',
        builder: (c, s) => const ErrorBoundary(
          label: 'route:/dev',
          child: DevConsoleScreen(),
        ),
      ),
    ],
  );
});

/// 役割別ホームへ振り分けるルーター（仕様書 §2 / §3.3）。
class _HomeRouter extends ConsumerWidget {
  const _HomeRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SetupState> setup = ref.watch(setupNotifierProvider);
    return setup.when(
      loading: () => const Scaffold(
        backgroundColor: TofuTokens.bgCanvas,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _MissingSetupView(),
      data: (data) => switch (data.role) {
        DeviceRole.register => const RegiHomeScreen(),
        DeviceRole.kitchen => const KitchenScreen(),
        DeviceRole.calling => const CallingScreen(),
        null => const _MissingSetupView(),
      },
    );
  }
}

class _MissingSetupView extends StatelessWidget {
  const _MissingSetupView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      body: Center(
        child: TextButton(
          onPressed: () => GoRouter.of(context).go('/setup/shop'),
          child: const Text('初期設定を開始'),
        ),
      ),
    );
  }
}

class _MissingOrderRedirect extends StatelessWidget {
  const _MissingOrderRedirect();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GoRouter.of(context).go('/');
    });
    return const Scaffold(
      backgroundColor: TofuTokens.bgCanvas,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// SetupState の変化を GoRouter の refreshListenable に流す ChangeNotifier。
class _SetupChangeNotifier extends ChangeNotifier {
  _SetupChangeNotifier(this._ref) {
    _ref.listen<AsyncValue<SetupState>>(setupNotifierProvider, (
      prev,
      next,
    ) {
      notifyListeners();
    });
  }
  final Ref _ref;
}
