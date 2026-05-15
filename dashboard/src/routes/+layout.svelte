<script lang="ts">
  import '../app.css';
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import ConnSettings from '$lib/components/ConnSettings.svelte';
  import { settings, hasEnvConnection, refreshFromEnv } from '$lib/stores/settings';
  import { startRealtime } from '$lib/stores/realtime';
  import { invalidateAll } from '$app/navigation';
  import {
    probeConnection,
    validateFormat,
    describe,
    severity,
    type HealthStatus,
  } from '$lib/connection_health';

  let { children } = $props();
  let settingsOpen = $state(false);
  let health = $state<HealthStatus>({ kind: 'idle' });

  async function checkHealth() {
    const s = $settings;
    const fmt = validateFormat(s);
    if (fmt.kind !== 'ok') {
      health = fmt;
      return;
    }
    // 形式 OK なら起動時に 1 度だけ疎通確認
    health = { kind: 'idle' };
    health = await probeConnection(s);
  }

  onMount(() => {
    refreshFromEnv();
    startRealtime();
    checkHealth();
  });

  // settings が変わったら (設定モーダル保存など) 再チェック
  $effect(() => {
    // 依存させたい値を読む
    void $settings.url;
    void $settings.key;
    checkHealth();
  });

  function reload() {
    invalidateAll();
    window.dispatchEvent(new CustomEvent('tofu:reload'));
    checkHealth();
  }

  let activeTab = $derived(page.url.pathname.startsWith('/tester') ? 'tester' : 'sales');
  let bannerText = $derived(describe(health));
  let bannerSeverity = $derived(severity(health));
  let showBanner = $derived(health.kind !== 'ok' && health.kind !== 'idle');
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
      {#if !hasEnvConnection()}
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
      class="rounded-md border px-4 py-3 text-sm"
      class:border-amber-300={bannerSeverity === 'warn'}
      class:bg-amber-50={bannerSeverity === 'warn'}
      class:text-amber-900={bannerSeverity === 'warn'}
      class:border-rose-300={bannerSeverity === 'error'}
      class:bg-rose-50={bannerSeverity === 'error'}
      class:text-rose-900={bannerSeverity === 'error'}
    >
      <div class="font-semibold">
        {bannerSeverity === 'error' ? '⚠ 接続エラー' : 'ℹ 未設定'}
      </div>
      <div class="mt-1 whitespace-pre-wrap break-words">{bannerText}</div>
      {#if health.kind === 'missing'}
        <div class="mt-1 text-xs opacity-80">
          {hasEnvConnection() ? 'デプロイ環境変数を確認してください。' : '右上の「⚙ 設定」を開いて入力してください。'}
        </div>
      {/if}
    </div>
  </div>
{/if}

{@render children()}

<ConnSettings bind:open={settingsOpen} onSaved={reload} />
