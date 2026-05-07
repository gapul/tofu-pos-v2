# Supabase Edge Functions

サーバ側でやりたい処理（バリデーション、権限制御、外部連携等）の置き場所。
現状は雛形のみで、本番デプロイは未実施。

## 一覧

### `cancel-order/`
注文取消の権限制御エンドポイント。
将来 RLS を厳格化したときに、クライアントから直接 update できなくして、
このFunction経由で取消するように切り替える想定。

## デプロイ手順

```bash
# Supabase CLI セットアップ
brew install supabase/tap/supabase
supabase login
supabase link --project-ref yixdoktyhtrkcnghbjnh

# デプロイ
supabase functions deploy cancel-order
```

## ローカル開発

```bash
supabase functions serve cancel-order --env-file .env.local
```

## Flutter からの呼び出し

```dart
final response = await Supabase.instance.client.functions.invoke(
  'cancel-order',
  body: {
    'shop_id': shopId,
    'local_order_id': orderId,
  },
);
```
