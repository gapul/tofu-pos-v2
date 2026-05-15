<script lang="ts">
  // 売上タブ: order_lines を取得して KPI / 時間帯 / 商品 / 属性 を表示。
  import { onMount, onDestroy } from 'svelte';
  import { settings, hasConnection } from '$lib/stores/settings';
  import { supabaseClient } from '$lib/supabase';
  import { fetchLines, aggregate, yen, type Aggregate } from '$lib/sales';
  import { resolveRange, startOfDay, addDays, isoDate, type RangeKind } from '$lib/time';
  import KpiCard from '$lib/components/KpiCard.svelte';
  import HourlyChart from '$lib/components/HourlyChart.svelte';
  import ProductRanking from '$lib/components/ProductRanking.svelte';
  import AttrBreakdown from '$lib/components/AttrBreakdown.svelte';
  import EmptyState from '$lib/components/EmptyState.svelte';

  function emptyAgg(): Aggregate {
    return {
      revenue: 0,
      orderCount: 0,
      cancelCount: 0,
      productRanking: [],
      hourlyRevenue: new Array(24).fill(0),
      ageCount: new Map(),
      genderCount: new Map(),
      groupCount: new Map(),
    };
  }

  let shop = $state($settings.shop ?? '');
  let range = $state<RangeKind>('today');
  let fromStr = $state(isoDate(addDays(startOfDay(new Date()), -6)));
  let toStr = $state(isoDate(startOfDay(new Date())));
  let errorMsg = $state('');
  let lastUpdatedAt = $state<Date | null>(null);
  let lineCount = $state(0);
  let agg = $state<Aggregate>(emptyAgg());
  let prev = $state<Aggregate>(emptyAgg()); // 前期間比較用
  let loading = $state(false);
  let hasLoadedOnce = $state(false);
  let now = $state(Date.now()); // 「○分前」の再描画トリガ

  const rangeOptions: Array<{ k: RangeKind; label: string }> = [
    { k: 'today', label: '本日' },
    { k: 'yesterday', label: '前日' },
    { k: 'last7', label: '直近7日' },
    { k: 'custom', label: '任意' },
  ];

  function previousRange(from: Date, to: Date): { from: Date; to: Date } {
    const span = to.getTime() - from.getTime();
    return { from: new Date(from.getTime() - span), to: new Date(to.getTime() - span) };
  }

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
    const prevRange = previousRange(from, to);
    loading = true;
    try {
      // 当期と前期を並列取得
      const [lines, prevLines] = await Promise.all([
        fetchLines(client, { shop: s, from, to }),
        fetchLines(client, { shop: s, from: prevRange.from, to: prevRange.to }),
      ]);
      agg = aggregate(lines);
      prev = aggregate(prevLines);
      lineCount = lines.length;
      lastUpdatedAt = new Date();
      hasLoadedOnce = true;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      errorMsg = `取得に失敗しました: ${msg}`;
      console.error(e);
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
    if (hasConnection($settings) && shop.trim()) {
      reload();
    }
    // 30 秒ごとに now を更新して相対時間表示を再計算
    tickTimer = setInterval(() => (now = Date.now()), 30_000);
    return () => window.removeEventListener('tofu:reload', handler);
  });
  onDestroy(() => {
    if (tickTimer) clearInterval(tickTimer);
  });

  // KPI 表示派生
  let avg = $derived(agg.orderCount > 0 ? agg.revenue / agg.orderCount : 0);
  let prevAvg = $derived(prev.orderCount > 0 ? prev.revenue / prev.orderCount : 0);

  function pct(curr: number, prev: number): number | null {
    if (!prev || prev === 0) return curr === 0 ? 0 : null;
    return ((curr - prev) / prev) * 100;
  }

  let revenueDelta = $derived(pct(agg.revenue, prev.revenue));
  let orderDelta = $derived(pct(agg.orderCount, prev.orderCount));
  let avgDelta = $derived(pct(avg, prevAvg));
  let cancelDelta = $derived(pct(agg.cancelCount, prev.cancelCount));

  let revenueSub = $derived(`売上対象 ${agg.orderCount.toLocaleString('ja-JP')} 件`);
  let cancelSub = $derived(
    agg.orderCount + agg.cancelCount > 0
      ? `取消率 ${((agg.cancelCount / (agg.orderCount + agg.cancelCount)) * 100).toFixed(1)}%`
      : '-',
  );

  // 相対時間表示
  function relativeFromNow(d: Date | null, _tick: number): string {
    if (!d) return '';
    const diffSec = Math.max(0, Math.floor((_tick - d.getTime()) / 1000));
    if (diffSec < 10) return 'たった今';
    if (diffSec < 60) return `${diffSec} 秒前`;
    if (diffSec < 3600) return `${Math.floor(diffSec / 60)} 分前`;
    if (diffSec < 86400) return `${Math.floor(diffSec / 3600)} 時間前`;
    return d.toLocaleString('ja-JP');
  }
  let updatedLabel = $derived(relativeFromNow(lastUpdatedAt, now));
  let freshness = $derived(
    !lastUpdatedAt
      ? 'idle'
      : now - lastUpdatedAt.getTime() < 60_000
        ? 'fresh'
        : now - lastUpdatedAt.getTime() < 600_000
          ? 'recent'
          : 'stale',
  );

  let needsShop = $derived(!shop.trim());
  let noData = $derived(hasLoadedOnce && !loading && agg.orderCount === 0 && agg.cancelCount === 0);
</script>

<main class="mx-auto max-w-6xl space-y-6 px-6 py-8">
  {#if errorMsg}
    <div class="rounded-lg border border-danger-border bg-danger-bg px-4 py-3 text-body-sm text-danger-text shadow-sm">
      {errorMsg}
    </div>
  {/if}

  <!-- フィルタバー -->
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
      <div>
        <div class="label">期間</div>
        <div class="flex rounded-md border border-border-subtle bg-surface p-0.5 text-body-sm-bold">
          {#each rangeOptions as opt}
            <button
              type="button"
              class="rounded px-3 py-1.5 transition"
              class:bg-canvas={range === opt.k}
              class:text-ink={range === opt.k}
              class:shadow-sm={range === opt.k}
              class:text-ink-tertiary={range !== opt.k}
              onclick={() => (range = opt.k)}>{opt.label}</button
            >
          {/each}
        </div>
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
      <button class="btn-primary" onclick={apply} disabled={loading}>
        {#if loading}<span class="inline-block h-3 w-3 animate-spin rounded-full border-2 border-brand-on border-r-transparent"></span>取得中…{:else}適用{/if}
      </button>
      <div class="ml-auto flex items-center gap-2 text-caption text-ink-tertiary">
        {#if updatedLabel}
          <span
            class="inline-block h-2 w-2 rounded-full"
            class:bg-status-online={freshness === 'fresh'}
            class:bg-status-syncing={freshness === 'recent'}
            class:bg-status-offline={freshness === 'stale'}
            class:bg-border-default={freshness === 'idle'}
          ></span>
          <span class="tabular">更新: {updatedLabel}{lineCount > 0 ? ` · ${lineCount.toLocaleString('ja-JP')} 行` : ''}</span>
        {/if}
      </div>
    </div>
  </section>

  {#if needsShop}
    <section class="card">
      <EmptyState
        icon="🏷️"
        title="店舗IDを入力してください"
        body="上のフォームに対象店舗の shop_id を入力して「適用」を押すと、その店舗の売上サマリが表示されます。"
        hint="例: yakisoba_A · takoyaki_main · matsuri-1"
      />
    </section>
  {:else if noData}
    <section class="card">
      <EmptyState
        icon="🍵"
        title="この期間のデータがありません"
        body={`shop_id "${shop.trim()}" の指定期間に注文が見つかりませんでした。期間を広げるか、店舗IDを確認してください。`}
        hint="「直近7日」を試すと取得範囲が広がります"
      />
    </section>
  {:else}
    <!-- KPI -->
    <section class="grid grid-cols-2 gap-4 md:grid-cols-4">
      <KpiCard label="売上合計" value={yen(agg.revenue)} sub={revenueSub} delta={revenueDelta} {loading} />
      <KpiCard
        label="注文件数"
        value={agg.orderCount.toLocaleString('ja-JP')}
        sub="取消除く"
        delta={orderDelta}
        {loading}
      />
      <KpiCard label="平均客単価" value={yen(avg)} delta={avgDelta} {loading} />
      <KpiCard
        label="取消件数"
        value={agg.cancelCount.toLocaleString('ja-JP')}
        sub={cancelSub}
        delta={cancelDelta}
        accent="danger"
        {loading}
      />
    </section>

    <!-- 時間帯 -->
    <section class="card">
      <div class="mb-4 flex items-baseline justify-between">
        <h2 class="text-body-bold text-ink">時間帯別売上</h2>
        <span class="text-caption text-ink-tertiary">JST · 24時間</span>
      </div>
      <HourlyChart hourly={agg.hourlyRevenue} />
    </section>

    <!-- 商品 + 属性 -->
    <div class="grid gap-4 md:grid-cols-2">
      <ProductRanking rows={agg.productRanking} />
      <AttrBreakdown age={agg.ageCount} gender={agg.genderCount} group={agg.groupCount} />
    </div>
  {/if}

  <footer class="pt-2 pb-8 text-center text-caption text-ink-tertiary">
    Tofu POS Dashboard · 読み取り専用 · データソース: <code class="rounded bg-surface px-1.5 py-0.5">order_lines</code>
    {#if revenueDelta !== null && !needsShop && !noData}
      · 前期比は同じ長さの直前期間との比較
    {/if}
  </footer>
</main>
