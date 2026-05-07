-- Tofu POS — 初期スキーマ
-- 仕様書 §8.2「1注文明細 = 1行」非正規化形式に準拠した単一テーブル設計。
-- アプリ側のローカルDB（drift）が正本、こちらは集計・分析用のミラー。

-- ===========================================================================
-- order_lines: 注文明細（クラウド側集約）
-- ===========================================================================
-- 各行 = 注文の1明細。同じ注文の複数明細は (shop_id, local_order_id) で同一性。
-- 取消は order_status='cancelled' / is_cancelled=true で表現（行は残す）。

create table if not exists public.order_lines (
  -- 複合キー: 端末側の注文ID + 明細番号
  shop_id              text        not null,
  local_order_id       integer     not null,
  line_no              integer     not null,

  -- 注文レベルの属性（同一注文の各行で重複）
  ticket_number        integer     not null,
  customer_age         text,
  customer_gender      text,
  customer_group       text,
  order_created_at     timestamptz not null,
  order_status         text        not null,
  is_cancelled         boolean     not null default false,

  -- 明細レベルの属性
  product_id           text        not null,
  product_name         text        not null,
  quantity             integer     not null,
  price_at_time_yen    integer     not null,
  total_item_price_yen integer     not null,
  discount_per_item_yen integer    not null default 0,

  -- 監査・運用
  synced_at            timestamptz not null default now(),

  primary key (shop_id, local_order_id, line_no)
);

-- 集計クエリ用のインデックス
create index if not exists idx_order_lines_shop_created
  on public.order_lines (shop_id, order_created_at desc);

create index if not exists idx_order_lines_shop_status
  on public.order_lines (shop_id, order_status);

-- ===========================================================================
-- RLS — v1 暫定（permissive）
-- ===========================================================================
-- v1 では auth を入れていないため、anon ロールに広めの権限を与える。
-- v2 で proper auth + shop_id ベースの絞り込みに切り替える。
-- TODO(security): 認証導入後、shop_id 単位でユーザーごとに制限する。

alter table public.order_lines enable row level security;

drop policy if exists "anon read" on public.order_lines;
create policy "anon read"
  on public.order_lines for select
  to anon
  using (true);

drop policy if exists "anon insert" on public.order_lines;
create policy "anon insert"
  on public.order_lines for insert
  to anon
  with check (true);

drop policy if exists "anon update" on public.order_lines;
create policy "anon update"
  on public.order_lines for update
  to anon
  using (true)
  with check (true);

-- 削除は許可しない（履歴の改ざん防止）
-- DELETE policy は意図的に作らない。

-- ===========================================================================
-- Realtime — 端末間連携用
-- ===========================================================================
-- Realtime は Supabase ダッシュボードから「Database > Replication」で
-- order_lines テーブルを有効化する必要がある。
-- ここでは publication への追加だけ宣言しておく。

alter publication supabase_realtime add table public.order_lines;
