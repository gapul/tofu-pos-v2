<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { settings, hasConnection } from '$lib/stores/settings';
  import { supabaseClient } from '$lib/supabase';
  import { fetchProducts, type ProductRow } from '$lib/master_data';
  import EmptyState from '$lib/components/EmptyState.svelte';

  let shop = $state($settings.shop ?? '');
  let rows = $state<ProductRow[]>([]);
  let errorMsg = $state('');
  let loading = $state(false);
  let hasLoadedOnce = $state(false);
  let lastUpdatedAt = $state<Date | null>(null);
  let now = $state(Date.now());
  let includeDeleted = $state(false);
  let sortBy = $state<'name' | 'price' | 'stock' | 'updated'>('name');
  let sortAsc = $state(true);

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
      rows = await fetchProducts(client, s);
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

  function setSort(col: typeof sortBy) {
    if (sortBy === col) sortAsc = !sortAsc;
    else {
      sortBy = col;
      sortAsc = true;
    }
  }

  const yen = (n: number) => '¥' + n.toLocaleString('ja-JP');

  let visible = $derived.by(() => {
    let list = rows;
    if (!includeDeleted) list = list.filter((r) => !r.is_deleted);
    const cmp = (a: ProductRow, b: ProductRow): number => {
      switch (sortBy) {
        case 'price':
          return a.price_yen - b.price_yen;
        case 'stock':
          return a.stock - b.stock;
        case 'updated':
          return a.updated_at.localeCompare(b.updated_at);
        case 'name':
        default:
          return a.name.localeCompare(b.name, 'ja');
      }
    };
    return [...list].sort((a, b) => (sortAsc ? cmp(a, b) : -cmp(a, b)));
  });

  let total = $derived(visible.length);
  let activeCount = $derived(rows.filter((r) => !r.is_deleted).length);
  let deletedCount = $derived(rows.filter((r) => r.is_deleted).length);
  let needsShop = $derived(!shop.trim());
  let noData = $derived(hasLoadedOnce && !loading && rows.length === 0);

  function colorStyle(c: number | null): string {
    if (c == null) return '';
    // ARGB int → CSS rgba。Flutter の Color.value 互換。
    const a = ((c >>> 24) & 0xff) / 255;
    const r = (c >>> 16) & 0xff;
    const g = (c >>> 8) & 0xff;
    const b = c & 0xff;
    return `background: rgba(${r}, ${g}, ${b}, ${a.toFixed(2)});`;
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
      <label class="flex items-center gap-2 text-body-sm text-ink-secondary">
        <input type="checkbox" bind:checked={includeDeleted} />
        削除済を表示
      </label>
      <button class="btn-primary" onclick={apply} disabled={loading}>
        {loading ? '取得中…' : '適用'}
      </button>
      <div class="ml-auto flex items-center gap-3 text-caption text-ink-tertiary tabular">
        <span>有効: {activeCount}</span>
        <span>削除済: {deletedCount}</span>
        {#if updatedLabel}<span>更新: {updatedLabel}</span>{/if}
      </div>
    </div>
  </section>

  {#if needsShop}
    <section class="card">
      <EmptyState icon="🏷️" title="店舗IDを入力してください" body="対象店舗の shop_id を入力して「適用」を押すと、その店舗の商品マスタが表示されます。" hint="例: yakisoba_A · takoyaki_main · matsuri-1" />
    </section>
  {:else if noData}
    <section class="card">
      <EmptyState icon="📦" title="商品マスタが登録されていません" body={`shop_id "${shop.trim()}" の products テーブルが空です。レジ端末で商品を登録すると自動でクラウドへ同期されます。`} hint="レジ端末: 設定 → 商品マスタ → 商品を追加" />
    </section>
  {:else}
    <section class="card overflow-hidden p-0">
      <table class="w-full text-body-sm">
        <thead class="border-b border-border-subtle bg-surface text-caption-bold uppercase tracking-wide text-ink-tertiary">
          <tr>
            <th class="px-4 py-3 text-left">色</th>
            <th class="cursor-pointer px-4 py-3 text-left hover:text-ink" onclick={() => setSort('name')}>
              商品名 {sortBy === 'name' ? (sortAsc ? '↑' : '↓') : ''}
            </th>
            <th class="cursor-pointer px-4 py-3 text-right hover:text-ink" onclick={() => setSort('price')}>
              価格 {sortBy === 'price' ? (sortAsc ? '↑' : '↓') : ''}
            </th>
            <th class="cursor-pointer px-4 py-3 text-right hover:text-ink" onclick={() => setSort('stock')}>
              在庫 {sortBy === 'stock' ? (sortAsc ? '↑' : '↓') : ''}
            </th>
            <th class="cursor-pointer px-4 py-3 text-left hover:text-ink" onclick={() => setSort('updated')}>
              更新 {sortBy === 'updated' ? (sortAsc ? '↑' : '↓') : ''}
            </th>
            <th class="px-4 py-3 text-left">状態</th>
          </tr>
        </thead>
        <tbody>
          {#each visible as r (r.product_id)}
            <tr class="border-b border-border-subtle/60 last:border-0" class:opacity-50={r.is_deleted}>
              <td class="px-4 py-2">
                <span class="inline-block h-5 w-5 rounded border border-border-subtle" style={colorStyle(r.display_color)}></span>
              </td>
              <td class="px-4 py-2 font-medium text-ink">
                {r.name}
                <div class="text-caption text-ink-tertiary tabular">{r.product_id}</div>
              </td>
              <td class="px-4 py-2 text-right tabular text-ink">{yen(r.price_yen)}</td>
              <td class="px-4 py-2 text-right tabular text-ink-secondary">{r.stock.toLocaleString('ja-JP')}</td>
              <td class="px-4 py-2 text-caption text-ink-tertiary tabular">
                {new Date(r.updated_at).toLocaleString('ja-JP')}
              </td>
              <td class="px-4 py-2">
                {#if r.is_deleted}
                  <span class="pill pill-danger">削除済</span>
                {:else}
                  <span class="pill pill-success">有効</span>
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </section>

    <footer class="pt-2 pb-8 text-center text-caption text-ink-tertiary">
      Tofu POS Dashboard · 読み取り専用 · データソース: <code class="rounded bg-surface px-1.5 py-0.5">products</code> · {total} 件表示
    </footer>
  {/if}
</main>
