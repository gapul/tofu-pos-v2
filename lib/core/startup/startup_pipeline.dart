import 'dart:async';

import '../logging/app_logger.dart';
import '../telemetry/telemetry.dart';

/// 起動パイプラインの 1 ステップ。
class StartupStep {
  const StartupStep({
    required this.name,
    required this.run,
    this.fatal = false,
  });

  /// テレメトリ・ログで識別するための名前（例: 'supabase.init'）。
  final String name;

  /// 実体。例外を投げてよい。
  final Future<void> Function() run;

  /// true の場合、失敗時に例外を再送出する。
  /// false の場合は Telemetry / Logger に記録して次へ進む。
  final bool fatal;
}

/// アプリ起動時の初期化シーケンスを直列に流すだけの薄い実行器。
///
/// 並列化や retry は意図的に持たない。順序が意味を持つ初期化を
/// 「順番に並べた小さな関数の集合」として宣言的に表現したかった、
/// ただそれだけの目的。
class StartupPipeline {
  const StartupPipeline(this.steps);

  final List<StartupStep> steps;

  Future<void> run() async {
    for (final StartupStep step in steps) {
      try {
        await step.run();
      } catch (e, st) {
        AppLogger.w('Startup step "${step.name}" failed', error: e, stackTrace: st);
        Telemetry.instance.error(
          'startup.step.failed',
          message: step.name,
          error: e,
          stackTrace: st,
          attrs: <String, Object?>{'step': step.name},
        );
        if (step.fatal) {
          rethrow;
        }
      }
    }
  }
}
