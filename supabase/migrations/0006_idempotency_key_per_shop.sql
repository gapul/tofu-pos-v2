-- Tofu POS — idempotency_key の UNIQUE スコープを `(shop_id, idempotency_key)` の複合に変更
-- 仕様書/コード参照: lib/core/sync/supabase_cloud_sync_client.dart
--
-- 背景:
--   0003_idempotency_key.sql で導入した partial UNIQUE は `idempotency_key`
--   単独だった。端末側は `(shop_id, local_order_id, line_no)` から UUID v5 を
--   決定論的に生成するため、同じ shop 内で衝突することはまずないが、
--   **複数店舗が同一テーブルを共有する** 構成（v1 以降のマルチテナント運用）
--   では、別店舗が偶然同じキーを生成した場合に衝突が発生しうる。
--
--   UNIQUE を `(shop_id, idempotency_key)` の複合に変えることで、
--   店舗間の名前空間衝突を防ぐ。NULL 値は引き続き許容する（旧データ後方互換）。
--
-- 既存環境での再適用は冪等（DROP IF EXISTS + CREATE IF NOT EXISTS）。

drop index if exists ux_order_lines_idempotency;

create unique index if not exists ux_order_lines_shop_idempotency
  on public.order_lines (shop_id, idempotency_key)
  where idempotency_key is not null;
