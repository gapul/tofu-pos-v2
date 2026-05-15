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

<section class="card space-y-5">
  <h2 class="text-body-bold text-ink">顧客属性内訳</h2>
  <div>
    <h3 class="label">年代</h3>
    <CategoryChart data={age} />
  </div>
  <div>
    <h3 class="label">性別</h3>
    <CategoryChart data={gender} />
  </div>
  <div>
    <h3 class="label">客層</h3>
    <CategoryChart data={group} />
  </div>
  <p class="text-caption text-ink-tertiary">※ 顧客属性入力オフ時に取得した注文は「未取得」に集計されます。</p>
</section>
