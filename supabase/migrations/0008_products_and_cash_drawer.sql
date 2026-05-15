-- Tofu POS — 商品マスタ / 釣銭スナップショットの Supabase 同期テーブル
--
-- 背景:
--   店舗 ID 入力後にローカル DB (Drift) の商品マスタと釣銭金種別在庫を
--   クラウドにアップロードして、ダッシュボード等から横断的に閲覧できる
--   ようにする。これまではローカル + device_events JSON 経由でしか
--   共有していなかった。
--
-- 設計:
--   - products: 商品マスタ。shop_id × product_id がプライマリキー。
--   - cash_drawer_snapshots: 釣銭スナップショット。shop_id × 金種(yen)
--     がプライマリキー。「いまの理論枚数」だけを保持 (履歴は持たない)。
--   - いずれも upsert で冪等に更新。
--   - RLS は 0001/0007 と同様に anon に open (v1 暫定)。

-- ===========================================================================
-- products
-- ===========================================================================
create table if not exists public.products (
  shop_id        text        not null,
  product_id     text        not null,
  name           text        not null,
  price_yen      integer     not null check (price_yen >= 0),
  stock          integer     not null default 0,
  display_color  integer,                          -- ARGB int or null
  is_deleted     boolean     not null default false,
  updated_at     timestamptz not null default now(),
  primary key (shop_id, product_id)
);

create index if not exists idx_products_shop_updated
  on public.products (shop_id, updated_at desc);

alter table public.products enable row level security;

drop policy if exists "anon read products" on public.products;
create policy "anon read products"
  on public.products for select
  to anon using (true);

drop policy if exists "anon insert products" on public.products;
create policy "anon insert products"
  on public.products for insert
  to anon with check (true);

drop policy if exists "anon update products" on public.products;
create policy "anon update products"
  on public.products for update
  to anon using (true) with check (true);

grant select, insert, update on public.products to anon;

-- ===========================================================================
-- cash_drawer_snapshots
-- ===========================================================================
-- 1 店舗あたり最大 9 行 (Denomination 全種)。常に上書き更新する想定。
create table if not exists public.cash_drawer_snapshots (
  shop_id          text        not null,
  denomination_yen integer     not null check (denomination_yen in (1,5,10,50,100,500,1000,5000,10000)),
  count            integer     not null default 0 check (count >= 0),
  updated_at       timestamptz not null default now(),
  primary key (shop_id, denomination_yen)
);

create index if not exists idx_cash_drawer_shop_updated
  on public.cash_drawer_snapshots (shop_id, updated_at desc);

alter table public.cash_drawer_snapshots enable row level security;

drop policy if exists "anon read cash_drawer" on public.cash_drawer_snapshots;
create policy "anon read cash_drawer"
  on public.cash_drawer_snapshots for select
  to anon using (true);

drop policy if exists "anon insert cash_drawer" on public.cash_drawer_snapshots;
create policy "anon insert cash_drawer"
  on public.cash_drawer_snapshots for insert
  to anon with check (true);

drop policy if exists "anon update cash_drawer" on public.cash_drawer_snapshots;
create policy "anon update cash_drawer"
  on public.cash_drawer_snapshots for update
  to anon using (true) with check (true);

grant select, insert, update on public.cash_drawer_snapshots to anon;

-- ===========================================================================
-- Realtime (ダッシュボード側のリアルタイム購読を可能にする)
-- ===========================================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'products'
  ) then
    alter publication supabase_realtime add table public.products;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cash_drawer_snapshots'
  ) then
    alter publication supabase_realtime add table public.cash_drawer_snapshots;
  end if;
end$$;
