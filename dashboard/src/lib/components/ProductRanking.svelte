<script lang="ts">
  import { yen } from '../sales';
  let { rows }: { rows: Array<{ name: string; qty: number; revenue: number }> } = $props();
</script>

<section class="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
  <h2 class="mb-3 text-sm font-semibold text-slate-700">商品別ランキング（上位10）</h2>
  {#if rows.length === 0}
    <div class="py-6 text-center text-sm text-slate-400">データなし</div>
  {:else}
    <table class="w-full text-sm">
      <thead class="border-b text-xs text-slate-500">
        <tr>
          <th class="py-1 text-left">#</th>
          <th class="py-1 text-left">商品</th>
          <th class="py-1 text-right">数量</th>
          <th class="py-1 text-right">売上</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-slate-100">
        {#each rows as r, i (r.name)}
          <tr>
            <td class="py-1.5 text-slate-400">{i + 1}</td>
            <td class="max-w-[200px] truncate py-1.5">{r.name}</td>
            <td class="py-1.5 text-right tabular-nums">{r.qty.toLocaleString('ja-JP')}</td>
            <td class="py-1.5 text-right tabular-nums">{yen(r.revenue)}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</section>
