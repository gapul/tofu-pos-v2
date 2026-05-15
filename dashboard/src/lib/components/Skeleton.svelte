<script lang="ts">
  let { height = 'h-24', width = 'w-full', rounded = 'rounded-lg' }: { height?: string; width?: string; rounded?: string } = $props();
</script>

<div class="{rounded} {height} {width} animate-pulse bg-surface-subtle/70"></div>

<style>
  /* tailwind の animate-pulse は opacity を 0.5↔1 で振る。
     和紙テクスチャに合わせて少し控えめにする。 */
</style>
