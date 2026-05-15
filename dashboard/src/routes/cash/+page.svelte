<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { settings, hasConnection } from '$lib/stores/settings';
  import { supabaseClient } from '$lib/supabase';
  import { fetchCashDrawer, ALL_DENOMINATIONS, type CashDrawerRow } from '$lib/master_data';
  import EmptyState from '$lib/components/EmptyState.svelte';

  let shop = $state($settings.shop ?? '');
  let rows = $state<CashDrawerRow[]>([]);
  let errorMsg = $state('');
  let loading = $state(false);
  let hasLoadedOnce = $state(false);
  let lastUpdatedAt = $state<Date | null>(null);
  let now = $state(Date.now());

  async function reload() {
    errorMsg = '';
    const client = $supabaseClient;
    if (!client) return;
    const s = shop.trim();
    if (!s) {
      errorMsg = '店舗IDを入力してください。';
      return;
    }
    loading = true;
    try {
      rows = await fetchCashDrawer(client, s);
      lastUpdatedAt = new Date();
      hasLoadedOnce = true;
    } catch (e) {
      errorMsg = `取得に失敗しました: ${e instanceof Error ? e.message : String(e)}`;
    } finally {
      loading = false;
    }
  }

  function apply() {
    settings.update((v) => ({ ...v, shop: shop.trim() }));
    reload();
  }

  let tickTimer: ReturnType<typeof setInterval> | null = null;
  onMount(() => {
    const handler = () => reload();
    window.addEventListener('tofu:reload', handler);
    if (hasConnection($settings) && shop.trim()) reload();
    tickTimer = setInterval(() => (now = Date.now()), 30_000);
    return () => window.removeEventListener('tofu:reload', handler);
  });
  onDestroy(() => {
    if (tickTimer) clearInterval(tickTimer);
  });

  function relativeFromNow(d: Date | null, tick: number): string {
    if (!d) return '';
    const diffSec = Math.max(0, Math.floor((tick - d.getTime()) / 1000));
    if (diffSec < 10) return 'たった今';
    if (diffSec < 60) return `${diffSec} 秒前`;
    if (diffSec < 3600) return `${Math.floor(diffSec / 60)} 分前`;
    if (diffSec < 86400) return `${Math.floor(diffSec / 3600)} 時間前`;
    return d.toLocaleString('ja-JP');
  }
  let updatedLabel = $derived(relativeFromNow(lastUpdatedAt, now));

  const yen = (n: number) => '¥' + n.toLocaleString('ja-JP');

  // 9 金種を必ず揃える (DB に無い金種は count=0 で表示)
  let byYen = $derived.by(() => {
    const m = new Map<number, CashDrawerRow>();
    for (const r of rows) m.set(r.denomination_yen, r);
    return ALL_DENOMINATIONS.map((y) => ({
      denomination_yen: y,
      count: m.get(y)?.count ?? 0,
      updated_at: m.get(y)?.updated_at ?? null,
      subtotal: y * (m.get(y)?.count ?? 0),
    }));
  });
  let total = $derived(byYen.reduce((s, r) => s + r.subtotal, 0));
  let coinTotal = $derived(byYen.filter((r) => r.denomination_yen < 1000).reduce((s, r) => s + r.subtotal, 0));
  let billTotal = $derived(byYen.filter((r) => r.denomination_yen >= 1000).reduce((s, r) => s + r.subtotal, 0));
  let needsShop = $derived(!shop.trim());
  let noData = $derived(hasLoadedOnce && !loading && rows.length === 0);

  function denomLabel(yen: number): string {
    if (yen >= 1000) return `${(yen / 1000).toLocaleString('ja-JP')} 千円札`;
    return `${yen.toLocaleString('ja-JP')} 円`;
  }
  function denomKind(yen: number): '硬貨' | '紙幣' {
    return yen >= 1000 ? '紙幣' : '硬貨';
  }
</script>

<main class="mx-auto max-w-6xl space-y-6 px-6 py-8">
  {#if errorMsg}
    <div class="rounded-lg border border-danger-border bg-danger-bg px-4 py-3 text-body-sm text-danger-text shadow-sm">
      {errorMsg}
    </div>
  {/if}

  <section class="card">
    <div class="flex flex-wrap items-end gap-x-6 gap-y-4">
      <div class="min-w-[12rem]">
        <label class="label" for="f-shop">店舗ID</label>
        <input
          id="f-shop"
          type="text"
          bind:value={shop}
          placeholder="yakisoba_A"
          class="input w-full"
          onkeydown={(e) => e.key === 'Enter' && apply()}
        />
      </div>
      <button class="btn-primary" onclick={apply} disabled={loading}>
        {loading ? '取得中…' : '適用'}
      </button>
      <div class="ml-auto text-caption text-ink-tertiary tabular">
        {#if updatedLabel}更新: {updatedLabel}{/if}
      </div>
    </div>
  </section>

  {#if needsShop}
    <section class="card">
      <EmptyState icon="🏷️" title="店舗IDを入力してください" body="対象店舗の shop_id を入力して「適用」を押すと、その店舗の釣銭スナップショットが表示されます。" hint="例: yakisoba_A · takoyaki_main · matsuri-1" />
    </section>
  {:else if noData}
    <section class="card">
      <EmptyState icon="🪙" title="釣銭スナップショットがありません" body={`shop_id "${shop.trim()}" の cash_drawer_snapshots テーブルが空です。レジ端末で「釣銭準備金を登録」を実施すると自動でクラウドへ同期されます。`} hint="レジ端末: 設定 → レジ締め → 釣銭準備金を登録" />
    </section>
  {:else}
    <section class="grid grid-cols-2 gap-4 md:grid-cols-3">
      <div class="card">
        <div class="absolute inset-x-0 top-0 h-1 bg-brand"></div>
        <div class="label">合計金額</div>
        <div class="mt-2 text-number-lg tabular text-ink">{yen(total)}</div>
      </div>
      <div class="card">
        <div class="absolute inset-x-0 top-0 h-1 bg-success-bgStrong"></div>
        <div class="label">硬貨計</div>
        <div class="mt-2 text-number-lg tabular text-ink">{yen(coinTotal)}</div>
      </div>
      <div class="card">
        <div class="absolute inset-x-0 top-0 h-1 bg-warning-bgStrong"></div>
        <div class="label">紙幣計</div>
        <div class="mt-2 text-number-lg tabular text-ink">{yen(billTotal)}</div>
      </div>
    </section>

    <section class="card overflow-hidden p-0">
      <table class="w-full text-body-sm">
        <thead class="border-b border-border-subtle bg-surface text-caption-bold uppercase tracking-wide text-ink-tertiary">
          <tr>
            <th class="px-4 py-3 text-left">金種</th>
            <th class="px-4 py-3 text-left">種別</th>
            <th class="px-4 py-3 text-right">枚数</th>
            <th class="px-4 py-3 text-right">小計</th>
            <th class="px-4 py-3 text-left">最終更新</th>
          </tr>
        </thead>
        <tbody>
          {#each byYen as r (r.denomination_yen)}
            <tr class="border-b border-border-subtle/60 last:border-0" class:opacity-50={r.count === 0}>
              <td class="px-4 py-2 font-medium text-ink">{denomLabel(r.denomination_yen)}</td>
              <td class="px-4 py-2 text-ink-tertiary">{denomKind(r.denomination_yen)}</td>
              <td class="px-4 py-2 text-right tabular text-ink">{r.count.toLocaleString('ja-JP')} 枚</td>
              <td class="px-4 py-2 text-right tabular text-ink">{yen(r.subtotal)}</td>
              <td class="px-4 py-2 text-caption text-ink-tertiary tabular">
                {r.updated_at ? new Date(r.updated_at).toLocaleString('ja-JP') : '-'}
              </td>
            </tr>
          {/each}
          <tr class="border-t-2 border-border-default bg-surface/50">
            <td class="px-4 py-3 text-body-sm-bold text-ink" colspan="3">合計</td>
            <td class="px-4 py-3 text-right text-body-sm-bold tabular text-ink">{yen(total)}</td>
            <td></td>
          </tr>
        </tbody>
      </table>
    </section>

    <footer class="pt-2 pb-8 text-center text-caption text-ink-tertiary">
      Tofu POS Dashboard · 読み取り専用 · データソース: <code class="rounded bg-surface px-1.5 py-0.5">cash_drawer_snapshots</code>
    </footer>
  {/if}
</main>
