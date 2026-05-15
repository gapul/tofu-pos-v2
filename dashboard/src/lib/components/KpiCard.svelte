<script lang="ts">
  let {
    label,
    value,
    sub,
    delta,
    deltaSuffix = '%',
    accent = 'default',
    loading = false,
  }: {
    label: string;
    value: string;
    sub?: string;
    delta?: number | null;
    deltaSuffix?: string;
    accent?: 'default' | 'danger' | 'success';
    loading?: boolean;
  } = $props();

  const accentBar = $derived(
    accent === 'danger' ? 'bg-danger-bgStrong' : accent === 'success' ? 'bg-success-bgStrong' : 'bg-brand',
  );
  const valueColor = $derived(
    accent === 'danger' ? 'text-danger-bgStrong' : accent === 'success' ? 'text-success-bgStrong' : 'text-ink',
  );
  const deltaPositive = $derived(typeof delta === 'number' && delta > 0);
  const deltaNegative = $derived(typeof delta === 'number' && delta < 0);
  const deltaText = $derived(
    typeof delta === 'number'
      ? (delta > 0 ? '▲' : delta < 0 ? '▼' : '–') + ' ' + Math.abs(delta).toFixed(1) + deltaSuffix
      : null,
  );
</script>

<div class="card relative overflow-hidden">
  <div class="absolute inset-x-0 top-0 h-1 {accentBar}"></div>
  <div class="flex items-start justify-between">
    <div class="label">{label}</div>
    {#if deltaText}
      <span
        class="rounded-full px-1.5 py-0.5 text-caption-bold tabular"
        class:bg-success-bg={deltaPositive && accent !== 'danger'}
        class:text-success-text={deltaPositive && accent !== 'danger'}
        class:bg-danger-bg={deltaNegative || (deltaPositive && accent === 'danger')}
        class:text-danger-text={deltaNegative || (deltaPositive && accent === 'danger')}
        class:bg-surface={delta === 0}
        class:text-ink-tertiary={delta === 0}
      >
        {deltaText}
      </span>
    {/if}
  </div>
  {#if loading}
    <div class="mt-3 h-9 w-32 animate-pulse rounded bg-surface-subtle/70"></div>
    <div class="mt-2 h-3 w-20 animate-pulse rounded bg-surface-subtle/40"></div>
  {:else}
    <div class="mt-2 text-number-lg tabular {valueColor}">{value}</div>
    {#if sub !== undefined}
      <div class="mt-1 text-caption text-ink-tertiary">{sub || '-'}</div>
    {/if}
  {/if}
</div>
