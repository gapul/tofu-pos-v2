-- Tofu POS — device_events: 端末間シグナリングイベント（仕様書 §7 オンライン主経路）
-- 仕様書/コード参照: lib/core/transport/supabase_transport.dart
--
-- このテーブルは「短命なシグナリング」専用:
--   - OrderSubmittedEvent / OrderServedEvent / CallNumberEvent / OrderCancelledEvent
--   - ProductMasterUpdateEvent
--
-- order_lines（永続データ）とは別の関心事。送信端末は INSERT、
-- 受信端末は Supabase Realtime の postgres_changes で購読する。
--
-- 学祭1日なら自然蓄積で問題ないが、長期運用時は inserted_at による
-- retention（例: 24時間以上経過した行を削除する cron）を検討。

create table if not exists public.device_events (
  id            bigserial    primary key,
  shop_id       text         not null,
  event_id      text         not null,
  event_type    text         not null,
  occurred_at   timestamptz  not null,
  payload       jsonb        not null,
  inserted_at   timestamptz  not null default now()
);

-- 同一イベントの再送を冪等に受け止めるためのユニーク制約。
create unique index if not exists ux_device_events_shop_event
  on public.device_events (shop_id, event_id);

-- 店舗ごとの新着順アクセス（受信側のページング・障害復旧時のリプレイ等）。
create index if not exists idx_device_events_shop_inserted
  on public.device_events (shop_id, inserted_at desc);

alter table public.device_events enable row level security;

drop policy if exists "anon read" on public.device_events;
create policy "anon read"
  on public.device_events for select
  to anon using (true);

drop policy if exists "anon insert" on public.device_events;
create policy "anon insert"
  on public.device_events for insert
  to anon with check (true);

-- 削除は許可しない（取り扱い注意：fest1日でクリアしないなら別途 cron で）。

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'device_events'
  ) then
    alter publication supabase_realtime add table public.device_events;
  end if;
end$$;
