<script lang="ts">
  let {
    label,
    value,
    sub,
    accent = 'default',
  }: {
    label: string;
    value: string;
    sub?: string;
    accent?: 'default' | 'danger';
  } = $props();
</script>

<div class="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
  <div class="text-xs text-slate-500">{label}</div>
  <div
    class="mt-1 text-2xl font-bold tabular-nums"
    class:text-rose-600={accent === 'danger'}
  >
    {value}
  </div>
  {#if sub !== undefined}
    <div class="mt-1 text-xs text-slate-400">{sub || '-'}</div>
  {/if}
</div>
