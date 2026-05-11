# 0004. 起動シーケンスを StartupPipeline に分解する

- Status: Accepted
- Date: 2026-05-08（JST）
- Deciders: gapul

## Context

旧実装は `main.dart` / `app.dart` に「Supabase 初期化 → Telemetry 初期化 → DailyReset → SyncService 起動 → RoleStarter」を直書きしていた。問題点:

- 1ステップが落ちると以降が走らない（順序によっては業務継続不能）
- どこで何秒かかったか観測できない
- 個別ステップを差し替えたテストが書きにくい
- 新しいステップ（例: `Env.validate()`）を割り込ませる箇所が散らばる

## Decision

起動シーケンスを **`StartupStep(name, run)` の列を順に await する `StartupPipeline`** に分解し、各ステップは:

1. 例外を Telemetry に `error(fatal: false)` で送って次へ進む
2. 名前と所要時間を `app_logger.event` で1行に記録する

順序は: `env.validate` → `supabase.init` → `telemetry.init` → `daily_reset` → `sync.start` → `role_starter.start`。

## Consequences

- 利点: 個々のステップの失敗が業務全体を止めない。
- 利点: 起動メトリクスがダッシュボードで可視化できる。
- 利点: テストでステップを差し替えやすい（`startup_pipeline_test.dart`）。
- 失うもの: 「どれかが失敗したら必ず止める」というドミノ的な保証は捨てた（必要なら `fatal: true` のステップを後で導入する）。
- 要観察: 新規ステップを足すときは並び順の意味（Env が先 / Sync は最後）を README または本 ADR に追記する。

## References

- ADR-0001: Supabase 初期化の遅延
- `lib/core/startup/startup_pipeline.dart`
- `lib/app.dart`
- `test/core/startup/startup_pipeline_test.dart`
