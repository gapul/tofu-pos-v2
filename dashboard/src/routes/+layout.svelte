<script lang="ts">
  import '../app.css';
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import ConnSettings from '$lib/components/ConnSettings.svelte';
  import { settings, hasConnection, hasEnvConnection } from '$lib/stores/settings';
  import { startRealtime } from '$lib/stores/realtime';
  import { invalidateAll } from '$app/navigation';

  let { children } = $props();
  let settingsOpen = $state(false);

  // 接続情報が揃ったらリアルタイム購読を起動
  onMount(() => {
    startRealtime();
  });

  let showBanner = $derived(!hasConnection($settings));

  function reload() {
    // 各ページで data-reload="..." のような連携を入れず、単純にナビゲーション無効化で再評価
    invalidateAll();
    // 売上タブでは window のイベントで再取得を起こす（簡易）
    window.dispatchEvent(new CustomEvent('tofu:reload'));
  }

  let activeTab = $derived(page.url.pathname.startsWith('/tester') ? 'tester' : 'sales');
</script>

<header class="border-b border-slate-200 bg-white">
  <div class="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
    <div class="flex items-center gap-2">
      <span class="text-2xl">🍢</span>
      <h1 class="text-lg font-bold tracking-tight">Tofu POS Dashboard</h1>
    </div>
    <div class="flex items-center gap-2 text-sm">
      <nav class="flex rounded-md bg-slate-100 p-0.5" role="tablist">
        <a
          href="/"
          class="rounded px-3 py-1"
          class:bg-white={activeTab === 'sales'}
          class:shadow-sm={activeTab === 'sales'}>📈 売上</a
        >
        <a
          href="/tester/"
          class="rounded px-3 py-1"
          class:bg-white={activeTab === 'tester'}
          class:shadow-sm={activeTab === 'tester'}>🧪 Tester</a
        >
      </nav>
      <button
        class="rounded-md bg-slate-100 px-3 py-1.5 hover:bg-slate-200"
        onclick={reload}>再読み込み</button
      >
      {#if !hasEnvConnection}
        <button
          class="rounded-md bg-slate-100 px-3 py-1.5 hover:bg-slate-200"
          onclick={() => (settingsOpen = true)}>⚙ 設定</button
        >
      {/if}
    </div>
  </div>
</header>

{#if showBanner}
  <div class="mx-auto max-w-6xl px-4 pt-4">
    <div
      class="rounded-md border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900"
    >
      Supabase の接続情報が未設定です。{hasEnvConnection ? 'デプロイ環境変数を確認してください。' : '右上の「⚙ 設定」を開いてください。'}
    </div>
  </div>
{/if}

{@render children()}

<ConnSettings bind:open={settingsOpen} onSaved={reload} />
