import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dev_console/presentation/screens/dev_console_screen.dart';

/// アプリ全体のルーティング定義。
///
/// Figma デザイン待ちのため、ホームは開発者用 DevConsole を表示している。
/// 本番UIが揃ったら `/` をロール別ホームに差し替え、`/dev` を本画面に移す。
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((
  Ref<GoRouter> ref,
) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const DevConsoleScreen(),
      ),
    ],
  );
});
