<script lang="ts">
  import EventStream from '$lib/components/EventStream.svelte';
</script>

<main class="mx-auto max-w-6xl space-y-6 px-4 py-6">
  <EventStream />
  <footer class="pt-2 pb-8 text-center text-xs text-slate-400">
    Tester · データソース: <code>telemetry_events</code> · Supabase Realtime 購読
  </footer>
</main>
