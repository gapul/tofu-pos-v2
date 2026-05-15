import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/env.dart';
import 'core/config/supabase_bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/startup/startup_pipeline.dart';
import 'core/telemetry/telemetry.dart';
import 'core/theme/app_theme.dart';
import 'providers/repository_providers.dart';
import 'providers/role_router_providers.dart';
import 'providers/sync_providers.dart';
import 'providers/telemetry_providers.dart';
import 'providers/usecase_providers.dart';

/// アプリ起動直後に1回だけ走る初期化シーケンス。
///
/// 順序:
///  0. Env 検証（Supabase 接続情報の形式チェック。失敗しても続行）
///  1. Supabase 初期化（iOS の起動 watchdog 回避のため第1フレーム後）
///  2. Telemetry 初期化（shop / device / role 確定後）
///  3. DailyReset（営業日切替の整理券プールリセット）
///  4. SyncService 起動
///  5. RoleStarter 起動
///
/// 個々の失敗は Telemetry に記録して次へ進む（fatal=false）。
StartupPipeline buildStartupPipeline(WidgetRef ref) {
  return StartupPipeline(<StartupStep>[
    StartupStep(
      name: 'env.validate',
      run: () async {
        final EnvValidation result = Env.validate();
        if (result is EnvInvalid) {
          // 致命扱いはしない。Supabase 周りは hasSupabaseCredentials の
          // ガードで自動的に Noop に落ちるため、検証エラーは観測対象に留める。
          Telemetry.instance.warn(
            'env.invalid',
            message: 'Env validation failed',
            attrs: <String, Object?>{
              'reasons': result.reasons.join('; '),
            },
          );
        }
      },
    ),
    const StartupStep(
      name: 'supabase.init',
      run: initializeSupabaseIfConfigured,
    ),
    StartupStep(
      name: 'telemetry.init',
      run: () => ref.read(telemetryInitProvider.future),
    ),
    StartupStep(
      name: 'daily_reset',
      run: () => ref.read(dailyResetUseCaseProvider).runIfNeeded(),
    ),
    StartupStep(
      name: 'ticket_pool.flush_pending',
      // 補償 release の失敗で積まれた pending を起動時に消化する。
      // 失敗しても fatal ではない（次回起動で再試行される）。
      run: () async {
        await ref
            .read(ticketNumberPoolRepositoryProvider)
            .flushPendingReleases();
      },
    ),
    StartupStep(
      name: 'sync.start',
      run: () async => ref.read(syncServiceProvider).start(),
    ),
    StartupStep(
      name: 'role_starter.start',
      run: () => ref.read(roleStarterProvider).start(),
    ),
  ]);
}

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
      await buildStartupPipeline(ref).run();
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
