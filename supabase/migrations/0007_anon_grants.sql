-- Tofu POS — anon ロールへの明示 GRANT
--
-- 背景:
--   0002 (telemetry_events) と 0004 (device_events) は RLS policy のみ宣言しており、
--   テーブルレベルの GRANT を Supabase のデフォルト付与に依存していた。
--   プロジェクトによって anon に対する INSERT が auto-grant されず、
--   実機から書き込み時に `permission denied for table ...` で蹴られるケースが発生する。
--
-- 対処:
--   permissive 運用前提のテーブル全てに対し、anon ロールへの GRANT を明示する。
--   v2 で proper auth に切り替える際に、ここを authenticated に絞り直す。
--
-- 冪等性:
--   GRANT は冪等。何度流しても安全。
--
-- 適用方法:
--   Supabase ダッシュボード → SQL Editor → 本ファイル全文貼り付け → Run。

-- order_lines: read / insert / update（delete は意図的に未付与）
grant select, insert, update on public.order_lines to anon;

-- telemetry_events: read / insert（update / delete は履歴改ざん防止）
grant select, insert on public.telemetry_events to anon;

-- device_events: read / insert（短命シグナリング、update / delete は不要）
grant select, insert on public.device_events to anon;

-- bigserial 採番のシーケンスにも USAGE が必要
grant usage on sequence public.telemetry_events_id_seq to anon;
grant usage on sequence public.device_events_id_seq to anon;
