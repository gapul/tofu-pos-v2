# Supabase 設定

## マイグレーションの適用

マイグレーションは **番号順に全部適用**する。同名の SQL を再実行しても冪等になるよう書いてあるので、追加マイグレーションが入った場合は最新のものだけを後から流せばよい。

| 番号 | ファイル | 目的 |
|---|---|---|
| 0001 | `migrations/0001_initial.sql` | `order_lines` テーブル + index + anon RLS + Realtime publication |
| 0002 | `migrations/0002_telemetry.sql` | `telemetry_events` テーブル + anon RLS |
| 0003 | `migrations/0003_idempotency_key.sql` | `order_lines.idempotency_key` 列追加 + partial UNIQUE index（端末側の冪等送信に対応） |
| 0004 | `migrations/0004_device_events.sql` | `device_events` テーブル（端末間シグナリング）+ anon RLS + Realtime publication。学祭1日なら自然蓄積で問題ないが、長期運用時は `inserted_at` による retention を検討。 |
| 0005 | `migrations/0005_device_events_retention.sql` | `device_events` の retention 運用ガイド（SQL コメントのみ。スキーマ変更なし）。長期運用時の手動 / pg_cron 削除レシピを記載。 |
| 0006 | `migrations/0006_idempotency_key_per_shop.sql` | `order_lines.idempotency_key` の UNIQUE スコープを `(shop_id, idempotency_key)` の複合に変更。マルチ店舗運用時のキー衝突を防ぐ。 |

### 方法 A: ダッシュボード SQL Editor（推奨・初回）

1. Supabase ダッシュボード → 左サイドバー **SQL Editor**
2. **New query** で空のクエリを開く
3. 上の表のファイルを順番に全文貼り付けて **Run**
4. 既に新版アプリを動かしている場合は、`0003_idempotency_key.sql` を未適用だと
   端末側の upsert が「unknown column `idempotency_key`」で失敗する。
   バージョンアップ時は必ず先に流すこと。

成功すると（0001 完了時点）:
- `public.order_lines` テーブルが作成される
- インデックス2本が貼られる
- RLS が有効化され、anon ロールに read/insert/update のポリシーが設定される
- Realtime publication に `order_lines` が追加される

### 方法 B: Supabase CLI

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref yixdoktyhtrkcnghbjnh
supabase db push
```

---

## v1 のセキュリティ前提

- 認証は未導入。anon キーがあれば誰でも `order_lines` を読み書きできる。
- 学祭1日の限定運用ならこれで十分だが、**長期運用や複数店舗運用時は必ず auth を入れる**。
- `DELETE` 操作は RLS ポリシーを意図的に作っていない。履歴の改ざんを防ぐため。

---

## Realtime の有効化

マイグレーションで publication への登録は完了するが、ダッシュボード側でも有効化が必要:

1. **Database** → **Replication**
2. `order_lines` テーブルの **Source** タブで **Enable Realtime** を ON
3. `device_events` テーブルでも同様に **Enable Realtime** を ON
   （`TransportMode.online` の端末間シグナリングに必須）
