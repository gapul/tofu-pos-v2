import 'package:meta/meta.dart';

import 'scenario_context.dart';

/// 自動テストの1シナリオ。
@immutable
class TestScenario {
  const TestScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.run,
  });

  final String id;
  final String name;
  final String description;
  final Future<ScenarioResult> Function(ScenarioContext ctx) run;
}

/// シナリオ実行結果。
///
/// 状態は3値:
///  - `passed = true`               → 成功
///  - `passed = false, skipped`     → 前提条件未満で実行できず（中立扱い）
///  - `passed = false, !skipped`    → 失敗
@immutable
class ScenarioResult {
  const ScenarioResult({
    required this.passed,
    required this.message,
    this.duration = Duration.zero,
    this.skipped = false,
  });

  factory ScenarioResult.pass(String message) =>
      ScenarioResult(passed: true, message: message);

  factory ScenarioResult.fail(String message) =>
      ScenarioResult(passed: false, message: message);

  /// 前提条件不足で実行できない場合。失敗ではなく中立扱い。
  factory ScenarioResult.skip(String reason) =>
      ScenarioResult(passed: false, skipped: true, message: 'SKIP: $reason');

  final bool passed;
  final bool skipped;
  final String message;
  final Duration duration;

  ScenarioResult withDuration(Duration d) => ScenarioResult(
    passed: passed,
    skipped: skipped,
    message: message,
    duration: d,
  );
}
