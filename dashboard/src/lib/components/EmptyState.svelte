<script lang="ts">
  let { icon = '📊', title, body, hint }: { icon?: string; title: string; body?: string; hint?: string } = $props();
</script>

<div class="grid place-items-center py-12 text-center">
  <div class="grid h-16 w-16 place-items-center rounded-full bg-surface text-3xl shadow-sm">{icon}</div>
  <h3 class="mt-4 text-h4 text-ink">{title}</h3>
  {#if body}<p class="mt-1 max-w-md text-body-sm text-ink-tertiary">{body}</p>{/if}
  {#if hint}<p class="mt-3 inline-block rounded-md border border-border-subtle bg-surface px-3 py-1.5 text-caption text-ink-secondary">{hint}</p>{/if}
</div>
