# 0002. 会計セッションは StateNotifier のまま据え置く

- Status: Accepted
- Date: 2026-05-08（JST）
- Deciders: gapul

## Context

Riverpod 2.x 系で `Notifier` / `AsyncNotifier` への移行が推奨されており、本プロジェクトも段階的に移行している。一方で、`CheckoutSession`（カート → 顧客属性 → 会計確定 → 印刷待ち）は **画面間で共有する短命な可変状態** を持ち、ライフサイクルが「お客様1組」と完全に一致する。

`Notifier` への素直な置き換えだと `ref.invalidate(checkoutSessionProvider)` を毎回呼ぶ必要があり、リセット忘れによる注文混入のリスクが上がる。`StateNotifier` のままなら `dispose()` を画面側で明示的に握れる。

## Decision

`CheckoutSession` は **`StateNotifier` のまま据え置く**。他の AsyncNotifier 移行とは別ルールとし、画面遷移と1対1で生成・破棄するセマンティクスを優先する。

## Consequences

- 利点: 「お客様1組分の状態」が型と寿命で表現される。リセット漏れが起きにくい。
- 利点: 既存テスト（`checkout_session_test.dart`）の互換性を保てる。
- 失うもの: Riverpod 公式推奨の最新 API から1機能だけズレる。新規参加者向けに ADR への導線が必要。
- 将来覆す条件: Riverpod が `Notifier` で同等のスコープ管理 API を提供したとき、または `StateNotifier` が deprecated になったとき。

## References

- ADR-0003: AsyncNotifier 移行方針
- `lib/features/regi/presentation/notifiers/checkout_session.dart`
- `test/features/regi/presentation/checkout_session_test.dart`
