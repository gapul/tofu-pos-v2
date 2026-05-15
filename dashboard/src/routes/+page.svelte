<script lang="ts">
  // 売上タブ: order_lines を取得して KPI / 時間帯 / 商品 / 属性 を表示。
  import { onMount } from 'svelte';
  import { settings, hasConnection } from '$lib/stores/settings';
  import { supabaseClient } from '$lib/supabase';
  import { fetchLines, aggregate, yen, type Aggregate } from '$lib/sales';
  import { resolveRange, startOfDay, addDays, isoDate, type RangeKind } from '$lib/time';
  import KpiCard from '$lib/components/KpiCard.svelte';
  import HourlyChart from '$lib/components/HourlyChart.svelte';
  import ProductRanking from '$lib/components/ProductRanking.svelte';
  import AttrBreakdown from '$lib/components/AttrBreakdown.svelte';

  let shop = $state($settings.shop ?? '');
  let range = $state<RangeKind>('today');
  let fromStr = $state(isoDate(addDays(startOfDay(new Date()), -6)));
  let toStr = $state(isoDate(startOfDay(new Date())));
  let errorMsg = $state('');
  let lastUpdated = $state('');
  let agg = $state<Aggregate>({
    revenue: 0,
    orderCount: 0,
    cancelCount: 0,
    productRanking: [],
    hourlyRevenue: new Array(24).fill(0),
    ageCount: new Map(),
    genderCount: new Map(),
    groupCount: new Map(),
  });

  async function reload() {
    errorMsg = '';
    const client = $supabaseClient;
    if (!client) return;
    const s = shop.trim();
    if (!s) {
      errorMsg = '店舗IDを入力してください。';
      return;
    }
    const { from, to } = resolveRange(range, fromStr, toStr);
    try {
      const lines = await fetchLines(client, { shop: s, from, to });
      agg = aggregate(lines);
      lastUpdated = `更新: ${new Date().toLocaleTimeString('ja-JP')} / ${lines.length} 行`;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      errorMsg = `取得に失敗しました: ${msg}`;
      console.error(e);
    }
  }

  function apply() {
    settings.update((v) => ({ ...v, shop: shop.trim() }));
    reload();
  }

  onMount(() => {
    const handler = () => reload();
    window.addEventListener('tofu:reload', handler);
    // 接続情報・店舗が揃っていれば初回ロード
    if (hasConnection($settings) && shop.trim()) {
      reload();
    }
    return () => window.removeEventListener('tofu:reload', handler);
  });

  let revenueSub = $derived(`売上対象 ${agg.orderCount} 件`);
  let avg = $derived(agg.orderCount > 0 ? agg.revenue / agg.orderCount : 0);
  let cancelSub = $derived(
    agg.orderCount + agg.cancelCount > 0
      ? `取消率 ${((agg.cancelCount / (agg.orderCount + agg.cancelCount)) * 100).toFixed(1)}%`
      : '-',
  );
</script>

<main class="mx-auto max-w-6xl space-y-6 px-6 py-8">
  {#if errorMsg}
    <div class="rounded-lg border border-danger-border bg-danger-bg px-4 py-3 text-body-sm text-danger-text shadow-sm">
      {errorMsg}
    </div>
  {/if}

  <section class="card">
    <div class="flex flex-wrap items-end gap-4">
      <div>
        <label class="label" for="f-shop">店舗ID</label>
        <input
          id="f-shop"
          type="text"
          bind:value={shop}
          placeholder="yakisoba_A"
          class="input w-48"
        />
      </div>
      <div>
        <label class="label" for="f-range">期間</label>
        <select id="f-range" bind:value={range} class="input">
          <option value="today">本日</option>
          <option value="yesterday">前日</option>
          <option value="last7">直近7日</option>
          <option value="custom">任意</option>
        </select>
      </div>
      {#if range === 'custom'}
        <div class="flex items-end gap-3">
          <div>
            <label class="label" for="f-from">開始</label>
            <input id="f-from" type="date" bind:value={fromStr} class="input" />
          </div>
          <div>
            <label class="label" for="f-to">終了</label>
            <input id="f-to" type="date" bind:value={toStr} class="input" />
          </div>
        </div>
      {/if}
      <button class="btn-primary" onclick={apply}>適用</button>
      <span class="ml-auto text-caption text-ink-tertiary tabular">{lastUpdated}</span>
    </div>
  </section>

  <section class="grid grid-cols-2 gap-4 md:grid-cols-4">
    <KpiCard label="売上合計" value={yen(agg.revenue)} sub={revenueSub} />
    <KpiCard
      label="注文件数"
      value={agg.orderCount.toLocaleString('ja-JP')}
      sub="取消除く"
    />
    <KpiCard label="平均客単価" value={yen(avg)} />
    <KpiCard
      label="取消件数"
      value={agg.cancelCount.toLocaleString('ja-JP')}
      sub={cancelSub}
      accent="danger"
    />
  </section>

  <section class="card">
    <h2 class="mb-4 text-body-bold text-ink">時間帯別売上</h2>
    <HourlyChart hourly={agg.hourlyRevenue} />
  </section>

  <div class="grid gap-4 md:grid-cols-2">
    <ProductRanking rows={agg.productRanking} />
    <AttrBreakdown age={agg.ageCount} gender={agg.genderCount} group={agg.groupCount} />
  </div>

  <footer class="pt-2 pb-8 text-center text-caption text-ink-tertiary">
    Tofu POS Dashboard · 読み取り専用 · データソース: <code class="rounded bg-surface px-1.5 py-0.5">order_lines</code>
  </footer>
</main>
