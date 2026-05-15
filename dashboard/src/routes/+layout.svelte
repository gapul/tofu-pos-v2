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
    health = { kind: 'idle' };
    health = await probeConnection(s);
  }

  onMount(() => {
    refreshFromEnv();
    startRealtime();
    checkHealth();
  });

  $effect(() => {
    void $settings.url;
    void $settings.key;
    checkHealth();
  });

  function reload() {
    invalidateAll();
    window.dispatchEvent(new CustomEvent('tofu:reload'));
    checkHealth();
  }

  let activeTab = $derived(
    page.url.pathname.startsWith('/tester')
      ? 'tester'
      : page.url.pathname.startsWith('/products')
        ? 'products'
        : page.url.pathname.startsWith('/cash')
          ? 'cash'
          : 'sales',
  );
  let bannerText = $derived(describe(health));
  let bannerSeverity = $derived(severity(health));
  let showBanner = $derived(health.kind !== 'ok' && health.kind !== 'idle');
</script>

<header class="sticky top-0 z-30 border-b border-border-subtle bg-canvas/85 backdrop-blur">
  <div class="mx-auto flex max-w-6xl items-center justify-between gap-4 px-6 py-3">
    <div class="flex items-center gap-3">
      <span class="grid h-9 w-9 place-items-center rounded-md bg-brand text-xl text-brand-on shadow-sm">🍢</span>
      <div class="leading-tight">
        <div class="text-h4 font-semibold tracking-tight text-ink">Tofu POS</div>
        <div class="text-caption text-ink-tertiary">Operations Dashboard</div>
      </div>
    </div>
    <div class="flex items-center gap-2">
      <nav class="flex rounded-md border border-border-subtle bg-surface p-0.5 text-body-sm-bold">
        <a
          href="/"
          class="rounded px-3 py-1.5 transition"
          class:bg-canvas={activeTab === 'sales'}
          class:text-ink={activeTab === 'sales'}
          class:shadow-sm={activeTab === 'sales'}
          class:text-ink-tertiary={activeTab !== 'sales'}>📈 売上</a
        >
        <a
          href="/products/"
          class="rounded px-3 py-1.5 transition"
          class:bg-canvas={activeTab === 'products'}
          class:text-ink={activeTab === 'products'}
          class:shadow-sm={activeTab === 'products'}
          class:text-ink-tertiary={activeTab !== 'products'}>📦 商品</a
        >
        <a
          href="/cash/"
          class="rounded px-3 py-1.5 transition"
          class:bg-canvas={activeTab === 'cash'}
          class:text-ink={activeTab === 'cash'}
          class:shadow-sm={activeTab === 'cash'}
          class:text-ink-tertiary={activeTab !== 'cash'}>🪙 釣銭</a
        >
        <a
          href="/tester/"
          class="rounded px-3 py-1.5 transition"
          class:bg-canvas={activeTab === 'tester'}
          class:text-ink={activeTab === 'tester'}
          class:shadow-sm={activeTab === 'tester'}
          class:text-ink-tertiary={activeTab !== 'tester'}>🧪 Tester</a
        >
      </nav>
      <button class="btn" onclick={reload} title="再読み込み">↻ 再読み込み</button>
      {#if !hasEnvConnection()}
        <button class="btn" onclick={() => (settingsOpen = true)} title="接続設定">⚙ 設定</button>
      {/if}
    </div>
  </div>
</header>

{#if showBanner}
  <div class="mx-auto max-w-6xl px-6 pt-4">
    <div
      class="rounded-lg border px-4 py-3 text-body-sm shadow-sm"
      class:border-warning-border={bannerSeverity === 'warn'}
      class:bg-warning-bg={bannerSeverity === 'warn'}
      class:text-warning-text={bannerSeverity === 'warn'}
      class:border-danger-border={bannerSeverity === 'error'}
      class:bg-danger-bg={bannerSeverity === 'error'}
      class:text-danger-text={bannerSeverity === 'error'}
    >
      <div class="text-body-sm-bold">
        {bannerSeverity === 'error' ? '⚠ 接続エラー' : 'ℹ 未設定'}
      </div>
      <div class="mt-1 whitespace-pre-wrap break-words">{bannerText}</div>
      {#if health.kind === 'missing'}
        <div class="mt-1 text-caption opacity-80">
          {hasEnvConnection() ? 'デプロイ環境変数を確認してください。' : '右上の「⚙ 設定」を開いて入力してください。'}
        </div>
      {/if}
    </div>
  </div>
{/if}

{@render children()}

<ConnSettings bind:open={settingsOpen} onSaved={reload} />
