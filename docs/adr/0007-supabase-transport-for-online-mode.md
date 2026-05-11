# 0007. オンラインモードの Transport を `device_events` テーブル経由で実装

- Status: Accepted
- Date: 2026-05-09（JST）
- Deciders: Tofu POS チーム

## Context

`TransportMode.online` は仕様書 §7.1 で「インターネット経由の端末間連携」と定義されていたが、初期実装は `NoopTransport` を返すスタブだった（包括 audit の致命指摘 #1）。デフォルトモードが `online` なので、出荷時の設定では会計確定がキッチンへ伝わらず、料理が始まらない致命バグだった。

選択肢:

1. **デフォルトを `bluetooth` に変える**（最短）。ただし仕様の「オンライン経路」を実装放棄することになる
2. **`order_lines` の Realtime を流用**（既存）。注文本体の同期と端末間シグナリングが混在する
3. **専用の `device_events` テーブルを新設**（採用案）

## Decision

**独立した `device_events` テーブルを設けて、Supabase Realtime の `postgres_changes` で購読する `SupabaseTransport` を実装する。**

- 送信: `device_events` への INSERT。`RetryPolicy` で短時間リトライ
- 受信: Realtime チャネル `tofu-pos:device-events:$shopId` 経由で INSERT イベントを購読
- 自端末のエコーバック対策: `_SelfIdRing(max=200)` で直近送信 ID を保持し、Realtime で戻ってきた自分の `event_id` を drop
- 認証情報なしの場合: `NoopTransport` に degrade（業務継続を優先）
- イベント種別の wire format: `event_type` 列に snake_case 文字列（`order_submitted` ほか）。Dart の sealed クラス名と decouple することでクラス名変更時の wire 破壊を防ぐ
- payload は jsonb 列。`encodePayload` / `decodeRow` を static にしてテスト容易性を確保

## Consequences

**得るもの**:
- 仕様書 §7.1 の `online` モードが本来の意味で動くようになる
- 端末間シグナリングと注文本体の同期（`order_lines`）が分離され、片方の障害がもう片方に波及しない
- スキーマ・チャネル名が独立しているので Realtime publication の有効化判定もしやすい

**失うもの**:
- マイグレーション 1 本（`0004_device_events.sql`）の追加運用コスト
- 学祭 1 日運用ではテーブルが自然蓄積する。長期運用時は `inserted_at` ベースの retention が要る
- v1 の RLS は anon read/insert 全許可（既存 `order_lines` と同じ前提）。Auth 導入時に併せて締める必要あり

**観察ポイント**:
- Realtime 接続の安定性（再接続、メッセージ消失の有無）
- エコーバック遅延 200 件分のバッファで十分か
- iOS / Android バックグラウンド時の Realtime 維持挙動

## References

- 関連コード: `lib/core/transport/supabase_transport.dart`, `lib/providers/usecase_providers.dart`
- 関連マイグレーション: `supabase/migrations/0004_device_events.sql`
- 関連 ADR: ADR-0001（Supabase 初期化遅延）/ ADR-0005（顧客 enum クラウド送信）
- 関連 issue: 包括 audit の致命指摘 #1
