# Supabase 設定

## マイグレーションの適用

### 方法 A: ダッシュボード SQL Editor（推奨・初回）

1. Supabase ダッシュボード → 左サイドバー **SQL Editor**
2. **New query** で空のクエリを開く
3. `migrations/0001_initial.sql` の中身を全部貼り付け
4. **Run** で実行

成功すると:
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
