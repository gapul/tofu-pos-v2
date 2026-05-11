-- Tofu POS — order_lines に冪等キーを追加
-- 仕様書/コード参照: lib/core/sync/supabase_cloud_sync_client.dart の冪等性ドキュメント。
--
-- 端末側は `(shop_id, local_order_id, line_no)` から決定論的に生成した
-- UUID v5 を `idempotency_key` として送る。ネットワーク再試行で同じ行を
-- 何度送ってもクラウド側は単一行として保持できる。
--
-- 既存行（このマイグレーション適用前に同期されたもの）には NULL が入る。
-- UNIQUE 制約は NULL を許容する partial index で実装し、後方互換を保つ。

alter table public.order_lines
  add column if not exists idempotency_key text;

-- 部分 UNIQUE: 値が入っている行同士でのみ衝突検査する。
-- 旧データ（NULL）は重複を許す。
create unique index if not exists ux_order_lines_idempotency
  on public.order_lines (idempotency_key)
  where idempotency_key is not null;
