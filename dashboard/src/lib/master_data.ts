// 商品マスタ / 釣銭スナップショットの取得ロジック。読み取り専用。
import type { SupabaseClient } from '@supabase/supabase-js';

export interface ProductRow {
  product_id: string;
  name: string;
  price_yen: number;
  stock: number;
  display_color: number | null;
  is_deleted: boolean;
  updated_at: string;
}

export interface CashDrawerRow {
  denomination_yen: number;
  count: number;
  updated_at: string;
}

export async function fetchProducts(
  supabase: SupabaseClient,
  shopId: string,
): Promise<ProductRow[]> {
  const { data, error } = await supabase
    .from('products')
    .select('product_id, name, price_yen, stock, display_color, is_deleted, updated_at')
    .eq('shop_id', shopId)
    .order('name', { ascending: true });
  if (error) throw error;
  return (data ?? []) as ProductRow[];
}

export async function fetchCashDrawer(
  supabase: SupabaseClient,
  shopId: string,
): Promise<CashDrawerRow[]> {
  const { data, error } = await supabase
    .from('cash_drawer_snapshots')
    .select('denomination_yen, count, updated_at')
    .eq('shop_id', shopId)
    .order('denomination_yen', { ascending: true });
  if (error) throw error;
  return (data ?? []) as CashDrawerRow[];
}

// 9 金種の定義 (UI の枠を常に揃えるため)。
export const ALL_DENOMINATIONS = [1, 5, 10, 50, 100, 500, 1000, 5000, 10000] as const;
