// order_lines テーブルの取得と集計ロジック。読み取り専用。
import type { SupabaseClient } from '@supabase/supabase-js';

export interface OrderLine {
  shop_id: string;
  local_order_id: string;
  line_no: number;
  ticket_number: number | null;
  customer_age: string | null;
  customer_gender: string | null;
  customer_group: string | null;
  order_created_at: string;
  order_status: string | null;
  is_cancelled: boolean | null;
  product_id: string | null;
  product_name: string;
  quantity: number | null;
  price_at_time_yen: number | null;
  total_item_price_yen: number | null;
  discount_per_item_yen: number | null;
}

export interface Aggregate {
  revenue: number;
  orderCount: number;
  cancelCount: number;
  productRanking: Array<{ name: string; qty: number; revenue: number }>;
  hourlyRevenue: number[];
  ageCount: Map<string, number>;
  genderCount: Map<string, number>;
  groupCount: Map<string, number>;
}

export async function fetchLines(
  supabase: SupabaseClient,
  args: { shop: string; from: Date; to: Date },
): Promise<OrderLine[]> {
  const { shop, from, to } = args;
  const { data, error } = await supabase
    .from('order_lines')
    .select(
      'shop_id,local_order_id,line_no,ticket_number,customer_age,customer_gender,customer_group,order_created_at,order_status,is_cancelled,product_id,product_name,quantity,price_at_time_yen,total_item_price_yen,discount_per_item_yen',
    )
    .eq('shop_id', shop)
    .gte('order_created_at', from.toISOString())
    .lt('order_created_at', to.toISOString())
    .order('order_created_at', { ascending: true })
    .limit(50000);
  if (error) throw error;
  return (data ?? []) as OrderLine[];
}

function bump(m: Map<string, number>, key: string | null | undefined) {
  const k = key && key.length > 0 ? key : '未取得';
  m.set(k, (m.get(k) ?? 0) + 1);
}

export function aggregate(lines: OrderLine[]): Aggregate {
  let revenue = 0;
  const orderIds = new Set<string>();
  const cancelOrderIds = new Set<string>();
  const productTotals = new Map<string, { qty: number; revenue: number }>();
  const hourlyRevenue = new Array<number>(24).fill(0);
  const ageCount = new Map<string, number>();
  const genderCount = new Map<string, number>();
  const groupCount = new Map<string, number>();
  const orderAttrs = new Map<
    string,
    { age: string | null; gender: string | null; group: string | null }
  >();

  for (const r of lines) {
    const orderKey = r.local_order_id;
    if (r.is_cancelled || r.order_status === 'cancelled') {
      cancelOrderIds.add(orderKey);
      continue;
    }
    orderIds.add(orderKey);
    const lineNet = (r.total_item_price_yen ?? 0) - (r.discount_per_item_yen ?? 0);
    revenue += lineNet;

    const p = productTotals.get(r.product_name) ?? { qty: 0, revenue: 0 };
    p.qty += r.quantity ?? 0;
    p.revenue += lineNet;
    productTotals.set(r.product_name, p);

    const hour = new Date(r.order_created_at).getHours();
    hourlyRevenue[hour] += lineNet;

    if (!orderAttrs.has(orderKey)) {
      orderAttrs.set(orderKey, {
        age: r.customer_age,
        gender: r.customer_gender,
        group: r.customer_group,
      });
    }
  }

  for (const a of orderAttrs.values()) {
    bump(ageCount, a.age);
    bump(genderCount, a.gender);
    bump(groupCount, a.group);
  }

  const productRanking = [...productTotals.entries()]
    .map(([name, v]) => ({ name, ...v }))
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 10);

  return {
    revenue,
    orderCount: orderIds.size,
    cancelCount: cancelOrderIds.size,
    productRanking,
    hourlyRevenue,
    ageCount,
    genderCount,
    groupCount,
  };
}

export const yen = (n: number) => '¥' + Math.round(n).toLocaleString('ja-JP');
