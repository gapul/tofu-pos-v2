-- display_color は Flutter の Color.value (ARGB unsigned 32-bit) を格納するため
-- 最大値が 4294967295 になる。postgres の integer (signed 32-bit, 2147483647) を
-- 超えるので bigint に拡張する。
alter table public.products
  alter column display_color type bigint using display_color::bigint;
