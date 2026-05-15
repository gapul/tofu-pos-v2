<script lang="ts">
  import { yen } from '../sales';
  let { rows }: { rows: Array<{ name: string; qty: number; revenue: number }> } = $props();
  const max = $derived(rows.length > 0 ? Math.max(...rows.map((r) => r.revenue)) : 0);
</script>

<section class="card">
  <h2 class="mb-4 text-body-bold text-ink">商品別ランキング <span class="text-caption text-ink-tertiary">上位10</span></h2>
  {#if rows.length === 0}
    <div class="py-8 text-center text-body-sm text-ink-tertiary">データなし</div>
  {:else}
    <table class="w-full text-body-sm">
      <thead>
        <tr class="border-b border-border-subtle text-caption-bold uppercase tracking-wide text-ink-tertiary">
          <th class="py-2 text-left font-medium">#</th>
          <th class="py-2 text-left font-medium">商品</th>
          <th class="py-2 text-right font-medium">数量</th>
          <th class="py-2 text-right font-medium">売上</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r, i (r.name)}
          <tr class="group border-b border-border-subtle/60 last:border-0">
            <td class="py-2 text-ink-tertiary tabular w-8">{i + 1}</td>
            <td class="relative max-w-[220px] py-2 pr-3">
              <div class="absolute inset-y-1 left-0 rounded bg-brand-subtle/60" style="width: {max > 0 ? (r.revenue / max) * 100 : 0}%; max-width: 100%;"></div>
              <span class="relative truncate font-medium text-ink">{r.name}</span>
            </td>
            <td class="py-2 text-right tabular text-ink-secondary">{r.qty.toLocaleString('ja-JP')}</td>
            <td class="py-2 text-right tabular font-medium text-ink">{yen(r.revenue)}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</section>
