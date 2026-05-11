# 0003. セットアップ系 Notifier は AsyncNotifier に統一する

- Status: Accepted
- Date: 2026-05-08（JST）
- Deciders: gapul

## Context

初期セットアップ画面（店舗ID・端末役割・ネットワーク確認）は I/O が多く、`SettingsRepository` への保存と検証を直列に行う。これまで `StateNotifier<AsyncValue<...>>` で実装していたが、

- `state = AsyncValue.loading()` の手動更新が散在
- エラー時の `AsyncValue.error(e, st)` で stack trace を取り損ねる
- `ref.read(...).future` でテストから状態を待ち合わせにくい

という問題があり、保守性が下がっていた。

## Decision

セットアップ系・初期化系の Notifier は **`AsyncNotifier`** に統一して移行する（既に完了）。`build()` で初期非同期処理を行い、副作用は専用メソッドで `state = AsyncValue.guard(...)` を使う。

ただし「画面1組のライフサイクルに紐づく短命な可変状態」（例: `CheckoutSession`）はこの方針の対象外（ADR-0002 を参照）。

## Consequences

- 利点: ローディング / エラー状態の取り扱いが一貫し、stack trace を必ず保持できる。
- 利点: テストで `await ref.read(provider.future)` の形が使え、`AsyncValue` のパターンマッチが減る。
- 失うもの: 既存 `StateNotifier` を使った画面の混在期間が一時的に発生する。
- 要観察: 移行残（StateNotifier ベースの provider）は `lib/features/startup/` 以外でも `git grep StateNotifier` で定期点検する。

## References

- ADR-0002: CheckoutSession の例外
- `lib/features/startup/presentation/setup_notifier.dart`
- `test/features/startup/presentation/setup_notifier_test.dart`
