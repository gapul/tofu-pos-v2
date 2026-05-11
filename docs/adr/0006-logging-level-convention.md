# 0006. ローカルログと Telemetry のレベル運用

- Status: Accepted
- Date: 2026-05-09（JST）
- Deciders: Tofu POS チーム

## Context

`AppLogger` と `Telemetry.instance` は別経路でログ/イベントを送る:

- **AppLogger**: 端末ローカル（開発時のコンソール、運用時のローカルログ）。
  デバッグ・運用現場での即時可視性が目的。
- **Telemetry**: クラウド（Supabase）に集約。横断的な不具合検知・集計が目的。

両者で同じ事象に異なるレベルを付けるケースが散見され、レビューで「StartupPipeline は warning ログだが error テレメトリ。意図？」と指摘された。意図はあるが暗黙だったので明文化する。

## Decision

**事象を 2 軸で評価して使い分ける**:

| 軸 | 判定 |
|---|---|
| ローカル運用上の重大度 | AppLogger のレベル |
| クラウドで横断検知したいか | Telemetry のレベル |

具体的な指針:

- **AppLogger.e (error)**: 端末上で業務継続に支障が出るレベル。注意喚起が必要。
- **AppLogger.w (warning)**: 想定外だが業務継続は可能。例: 1 ステップの失敗、リトライで回復見込み。
- **AppLogger.i (info)**: 正常系の重要イベント（起動完了など）。
- **Telemetry.error**: クラウドで「件数が増えたら気づきたい」事象。
  StartupPipeline の各ステップ失敗、SyncService の継続失敗、JSON パース失敗など。
  ローカル的には warning 相当でも、**集計対象としては error** として扱う。
- **Telemetry.warn**: 集計対象だが個別に追わない事象。Env 検証 NG など。
- **Telemetry.event**: 平常時のメトリクス。`sync.run` 成功カウントなど。

非対称が許容される例:

```dart
AppLogger.w('Startup step "$name" failed', error: e); // ローカル: 続行可能
Telemetry.instance.error('startup.step.failed', ...);  // クラウド: 集計対象
```

## Consequences

- **得るもの**: ローカル運用と集計運用を分離して設計できる。「現場でアラート上げる」と「事後に件数を見る」が別のレベルとして表現可能。
- **失うもの**: 統一感は無くなる。最初に見る人は混乱しがち。本 ADR を読めば解消する想定。
- **観察ポイント**: 「ローカル warning、クラウド error」が一貫していること。
  逆（ローカル error、クラウド info）は基本的に NG。

## References

- 関連コード: `lib/core/startup/startup_pipeline.dart`, `lib/core/logging/app_logger.dart`, `lib/core/telemetry/telemetry.dart`
- 関連 ADR: なし
