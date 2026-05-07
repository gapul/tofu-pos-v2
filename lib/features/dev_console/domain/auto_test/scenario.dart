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
@immutable
class ScenarioResult {
  const ScenarioResult({
    required this.passed,
    required this.message,
    this.duration = Duration.zero,
  });

  factory ScenarioResult.pass(String message) =>
      ScenarioResult(passed: true, message: message);

  factory ScenarioResult.fail(String message) =>
      ScenarioResult(passed: false, message: message);

  final bool passed;
  final String message;
  final Duration duration;

  ScenarioResult withDuration(Duration d) =>
      ScenarioResult(passed: passed, message: message, duration: d);
}
