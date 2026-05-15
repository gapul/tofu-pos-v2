<script lang="ts">
  import CategoryChart from './CategoryChart.svelte';
  let {
    age,
    gender,
    group,
  }: {
    age: Map<string, number>;
    gender: Map<string, number>;
    group: Map<string, number>;
  } = $props();
</script>

<section class="space-y-4 rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
  <h2 class="text-sm font-semibold text-slate-700">顧客属性内訳</h2>
  <div>
    <h3 class="mb-1 text-xs text-slate-500">年代</h3>
    <CategoryChart data={age} />
  </div>
  <div>
    <h3 class="mb-1 text-xs text-slate-500">性別</h3>
    <CategoryChart data={gender} />
  </div>
  <div>
    <h3 class="mb-1 text-xs text-slate-500">客層</h3>
    <CategoryChart data={group} />
  </div>
  <p class="text-xs text-slate-400">※ 顧客属性入力オフ時に取得した注文は「未取得」に集計されます。</p>
</section>
