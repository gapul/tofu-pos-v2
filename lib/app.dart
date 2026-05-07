import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/role_router_providers.dart';
import 'providers/sync_providers.dart';
import 'providers/telemetry_providers.dart';
import 'providers/usecase_providers.dart';

/// アプリ起動直後に1回だけ走る初期化。
///
/// - DailyReset（営業日切替の整理券プールリセット）
/// - SyncService.start（オンライン同期）
/// - RoleStarter.start（役割別ルーター/サービスの起動）
class _StartupInitializer extends ConsumerStatefulWidget {
  const _StartupInitializer({required this.child});
  final Widget child;

  @override
  ConsumerState<_StartupInitializer> createState() =>
      _StartupInitializerState();
}

class _StartupInitializerState extends ConsumerState<_StartupInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 0. テレメトリの初期化（shop / device / role が確定後に有効化）
      await ref.read(telemetryInitProvider.future);
      // 1. 営業日切替チェック → 整理券プールのリセット
      await ref.read(dailyResetUseCaseProvider).runIfNeeded();
      // 2. クラウド同期の自動起動
      ref.read(syncServiceProvider).start();
      // 3. 役割別のルーター/自動ブロードキャスター起動
      await ref.read(roleStarterProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class TofuPosApp extends ConsumerWidget {
  const TofuPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    return _StartupInitializer(
      child: MaterialApp.router(
        title: 'Tofu POS',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
