# 0005. 顧客属性を enum 名のままクラウドに送る

- Status: Accepted
- Date: 2026-05-11（JST）
- Deciders: gapul

## Context

`SupabaseCloudSyncClient.buildRows()`（`lib/core/sync/supabase_cloud_sync_client.dart` の 50-52 行付近）は、
1 明細 1 行の `order_lines` テーブルに以下 3 つの顧客属性カラムを送る:

- `customer_age` ← `CustomerAge` enum の `name`（例: `twenties`, `thirties`）
- `customer_gender` ← `CustomerGender` enum の `name`（例: `female`, `male`）
- `customer_group` ← `CustomerGroup` enum の `name`（例: `family`, `couple`）

入力時点で **粗いバケット**に量子化されており、生の年齢・氏名・連絡先等は端末側にも
クラウド側にも一切存在しない。設計上の前提は仕様書 §6.1.2 / §10（プライバシー方針）。

## Decision

enum の `name` をそのまま文字列としてクラウドへ送る現状の挙動を維持する。

- 受け取り側の Supabase スキーマは該当カラムを `text` または `enum` 型で保持する。
- **生の年齢（integer）など細粒度値に変更しない。**「20 代後半」程度の粒度に量子化済みであることが
  PII 取扱を「coarse demographics（粗い属性集計）」の範囲に留めるための前提条件である。
- `PiiRedactor`（テレメトリ送信用の個人情報マスカー）はこれらの enum 名を
  「PII ではない」として通過させてよい。

## Consequences

- 利点: 集計クエリが SQL レベルで人間可読（`WHERE customer_age = 'twenties'`）。
- 利点: スキーマ変更なしに enum を追加できる（既存値は壊れない）。
- 利点: 端末・クラウド両側で「個人を特定できない粗いバケット」という不変条件が守られる。
- 失うもの: 「将来生年月日や年齢そのものを送りたい」要望には応えられない。これは **意図された hard constraint** である。
- **トリガー条件 (本 ADR の再レビューが必要なケース)**:
  - `order_lines` のスキーマで `customer_age` を `int` などの数値型に変更しようとした場合
  - enum を細分化して 5 歳刻みなど fine-grained にしようとした場合
  - 顧客属性に氏名・連絡先・座席番号等の識別性のあるフィールドを追加しようとした場合
  上記のいずれかを行うときは、本 ADR を Superseded 化 + `PiiRedactor` の拡張をセットで検討する。

## References

- 関連コード: `lib/core/sync/supabase_cloud_sync_client.dart` (buildRows 内コメント参照)
- 関連 enum: `lib/domain/enums/customer_age.dart` / `customer_gender.dart` / `customer_group.dart`
- 関連: `lib/core/telemetry/pii_redactor.dart`
- 仕様書: §6.1.2（顧客属性入力）, §10（プライバシー）
