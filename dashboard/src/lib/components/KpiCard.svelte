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
    accent?: 'default' | 'danger' | 'success';
  } = $props();
</script>

<div
  class="card relative overflow-hidden"
  class:before:bg-brand={accent === 'default'}
  class:before:bg-danger-bgStrong={accent === 'danger'}
  class:before:bg-success-bgStrong={accent === 'success'}
>
  <div class="absolute inset-x-0 top-0 h-1" class:bg-brand={accent === 'default'} class:bg-danger-bgStrong={accent === 'danger'} class:bg-success-bgStrong={accent === 'success'}></div>
  <div class="label">{label}</div>
  <div
    class="mt-2 text-number-lg tabular text-ink"
    class:text-danger-bgStrong={accent === 'danger'}
    class:text-success-bgStrong={accent === 'success'}
  >
    {value}
  </div>
  {#if sub !== undefined}
    <div class="mt-1 text-caption text-ink-tertiary">{sub || '-'}</div>
  {/if}
</div>
