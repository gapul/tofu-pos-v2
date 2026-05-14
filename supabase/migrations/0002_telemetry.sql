-- Tofu POS — テレメトリ（実機テスト用ライブイベント）
-- 仕様書 §11 / docs/MANUAL_TEST_RUNBOOK.md
--
-- 端末から発行された構造化イベントを集約する。
-- ダッシュボードの Tester タブが Realtime postgres_changes で購読し、
-- 「ちゃんと動いているか」と「エラー」をライブ表示する。
-- 業務データではないので、運用ログ的な扱い（30日 retention 推奨）。

create table if not exists public.telemetry_events (
  id            bigserial    primary key,
  occurred_at   timestamptz  not null default now(),
  shop_id       text         not null,
  device_id     text         not null,
  device_role   text         not null,
  scenario_id   text,
  app_version   text,
  level         text         not null check (level in ('debug','info','warn','error')),
  kind          text         not null,
  message       text,
  attrs         jsonb        not null default '{}'::jsonb
);

-- 取得頻度の高い「最新順」「店舗 × 期間」の引きを最適化
create index if not exists idx_telemetry_shop_time
  on public.telemetry_events (shop_id, occurred_at desc);

-- エラーだけ抜く用
create index if not exists idx_telemetry_errors
  on public.telemetry_events (shop_id, occurred_at desc)
  where level = 'error';

-- シナリオ単位の引き
create index if not exists idx_telemetry_scenario
  on public.telemetry_events (scenario_id, occurred_at)
  where scenario_id is not null;

-- ===========================================================================
-- RLS — v1 暫定（permissive）
-- ===========================================================================
-- order_lines と同じく、v1 では auth を入れていないため anon に書き込みを許可。
-- v2 で proper auth + shop_id ベースの絞り込みに切り替える。

alter table public.telemetry_events enable row level security;

drop policy if exists "anon read" on public.telemetry_events;
create policy "anon read"
  on public.telemetry_events for select
  to anon
  using (true);

drop policy if exists "anon insert" on public.telemetry_events;
create policy "anon insert"
  on public.telemetry_events for insert
  to anon
  with check (true);

-- update / delete は許可しない（履歴の改ざん防止）

-- ===========================================================================
-- Realtime
-- ===========================================================================
-- ダッシュボードの Tester タブが postgres_changes で購読する。
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'telemetry_events'
  ) then
    alter publication supabase_realtime add table public.telemetry_events;
  end if;
end$$;

-- ===========================================================================
-- Retention（任意）
-- ===========================================================================
-- 学祭規模なら30日も持てば十分。pg_cron がある環境では schedule で実行を推奨。
-- create extension if not exists pg_cron;
-- select cron.schedule(
--   'telemetry-retention',
--   '0 4 * * *',
--   $$delete from public.telemetry_events where occurred_at < now() - interval '30 days'$$
-- );
