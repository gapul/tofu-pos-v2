// 注文取消の権限制御 Edge Function（雛形）
//
// 仕様書 §6.6: 取消は「履歴ベースの信用制御」とするが、
// 将来的に複数店舗運用や認証導入時、ここでの権限チェックに切り替える想定。
//
// 現状はクライアントから直接 order_lines を update できる（暫定 RLS）。
// この関数を経由する形に切り替えれば:
//   - 取り消し可能な期間制限（例: 注文確定から30分以内）
//   - 操作者の認証情報の検証
//   - ログの一元管理
// が可能になる。
//
// デプロイ:
//   supabase functions deploy cancel-order
//
// 呼び出し（Flutter 側）:
//   final res = await Supabase.instance.client.functions.invoke(
//     'cancel-order',
//     body: {'shop_id': shopId, 'local_order_id': orderId},
//   );

import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

interface CancelRequest {
  shop_id: string;
  local_order_id: number;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  const body = (await req.json()) as CancelRequest;
  if (!body.shop_id || typeof body.local_order_id !== 'number') {
    return new Response(
      JSON.stringify({ error: 'shop_id and local_order_id required' }),
      { status: 400, headers: { 'content-type': 'application/json' } },
    );
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // TODO: 取り消し可能期間チェック等のビジネスルール
  // const { data: existing } = await supabase
  //   .from('order_lines')
  //   .select('order_created_at')
  //   .eq('shop_id', body.shop_id)
  //   .eq('local_order_id', body.local_order_id)
  //   .limit(1)
  //   .single();
  // if (existing && Date.now() - new Date(existing.order_created_at).getTime() > 30 * 60 * 1000) {
  //   return new Response(JSON.stringify({ error: 'too_old_to_cancel' }), { status: 403 });
  // }

  const { error } = await supabase
    .from('order_lines')
    .update({
      order_status: 'cancelled',
      is_cancelled: true,
      synced_at: new Date().toISOString(),
    })
    .eq('shop_id', body.shop_id)
    .eq('local_order_id', body.local_order_id);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'content-type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ status: 'ok' }), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
});
