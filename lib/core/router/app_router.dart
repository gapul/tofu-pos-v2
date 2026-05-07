import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// アプリ全体のルーティング定義（Phase 0 のスケルトン）。
///
/// Phase 4 で各画面を実装する際に分岐ロジック（ShopID未設定→ShopIdScreen、
/// Role未選択→RoleSelection、Role別ホーム）を組み込む。
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref<GoRouter> ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const _PlaceholderHome(),
      ),
    ],
  );
});

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tofu POS')),
      body: const Center(
        child: Text('セットアップ中（Phase 0 完了）'),
      ),
    );
  }
}
