<script lang="ts">
  import {
    events,
    errors,
    liveStatus,
    clearEvents,
    clearErrors,
    levelMatches,
    shortDevice,
    type TelemetryEvent,
  } from '../stores/realtime';
  import { formatTime } from '../time';

  let filter = $state('');
  let level = $state('');
  let now = $state(Date.now());

  // 1 秒ごとに集計用カウンタを更新
  $effect(() => {
    const t = setInterval(() => (now = Date.now()), 1000);
    return () => clearInterval(t);
  });

  function rowMatchesFilter(row: TelemetryEvent): boolean {
    if (level && !levelMatches(row.level, level)) return false;
    if (!filter) return true;
    const f = filter.toLowerCase();
    return (
      (row.kind ?? '').toLowerCase().includes(f) ||
      (row.device_id ?? '').toLowerCase().includes(f) ||
      (row.device_role ?? '').toLowerCase().includes(f) ||
      (row.message ?? '').toLowerCase().includes(f)
    );
  }

  let visibleEvents = $derived($events.filter(rowMatchesFilter).slice(0, 200));

  let recent1m = $derived(
    $events.filter((e) => new Date(e.occurred_at).getTime() >= now - 60_000).length,
  );
  let errors1h = $derived(
    $errors.filter((e) => new Date(e.occurred_at).getTime() >= now - 3_600_000).length,
  );
  let devicesActive = $derived(new Set($events.map((e) => e.device_id)).size);
  let lastSeen = $derived(
    $events[0] ? formatTime(new Date($events[0].occurred_at)) : '-',
  );

  // kind × device 集計
  let kindRows = $derived.by(() => {
    const byKind = new Map<string, { total: number; byDevice: Map<string, number> }>();
    for (const e of $events) {
      const k = e.kind;
      if (!byKind.has(k)) byKind.set(k, { total: 0, byDevice: new Map() });
      const slot = byKind.get(k)!;
      slot.total++;
      const dev = shortDevice(e.device_role, e.device_id);
      slot.byDevice.set(dev, (slot.byDevice.get(dev) ?? 0) + 1);
    }
    return [...byKind.entries()]
      .sort((a, b) => b[1].total - a[1].total)
      .slice(0, 30)
      .map(([kind, agg]) => ({
        kind,
        total: agg.total,
        devices: [...agg.byDevice.entries()].sort((a, b) => b[1] - a[1]),
      }));
  });

  let statusLabel = $derived(
    $liveStatus === 'live'
      ? 'ライブ受信中'
      : $liveStatus === 'connecting'
        ? '接続中…'
        : $liveStatus === 'idle'
          ? '未接続'
          : `切断 (${$liveStatus})`,
  );
</script>

<section class="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
  <div class="mb-3 flex items-center justify-between">
    <h2 class="text-sm font-semibold text-slate-700">ライブステータス</h2>
    <div class="flex items-center gap-2 text-xs">
      <span
        class="live-dot inline-block h-2 w-2 rounded-full bg-slate-300"
        class:live={$liveStatus === 'live'}
      ></span>
      <span class="text-slate-500">{statusLabel}</span>
    </div>
  </div>
  <div class="grid grid-cols-2 gap-3 text-sm md:grid-cols-4">
    <div class="rounded border border-slate-200 p-3">
      <div class="text-xs text-slate-500">直近1分のイベント</div>
      <div class="mt-1 text-xl font-bold tabular-nums">{recent1m.toLocaleString('ja-JP')}</div>
    </div>
    <div class="rounded border border-slate-200 p-3">
      <div class="text-xs text-slate-500">エラー（直近1時間）</div>
      <div class="mt-1 text-xl font-bold tabular-nums text-rose-600">
        {errors1h.toLocaleString('ja-JP')}
      </div>
    </div>
    <div class="rounded border border-slate-200 p-3">
      <div class="text-xs text-slate-500">アクティブ端末</div>
      <div class="mt-1 text-xl font-bold tabular-nums">{devicesActive.toLocaleString('ja-JP')}</div>
    </div>
    <div class="rounded border border-slate-200 p-3">
      <div class="text-xs text-slate-500">最終受信</div>
      <div class="mt-1 text-xl font-bold tabular-nums text-slate-700">{lastSeen}</div>
    </div>
  </div>
</section>

<section class="rounded-lg border border-rose-200 bg-white p-4 shadow-sm">
  <div class="mb-2 flex items-center justify-between">
    <h2 class="text-sm font-semibold text-rose-700">エラー（リアルタイム）</h2>
    <button class="text-xs text-slate-500 hover:text-slate-800" onclick={clearErrors}>クリア</button>
  </div>
  {#if $errors.length === 0}
    <div class="py-4 text-center text-sm text-slate-400">エラーなし</div>
  {:else}
    <ul class="max-h-64 space-y-1 overflow-y-auto text-sm">
      {#each $errors.slice(0, 50) as e (e.id)}
        <li class="rounded border border-rose-100 bg-rose-50/50 px-3 py-2">
          <div class="flex items-center justify-between text-xs text-rose-700">
            <span class="font-mono">{e.kind}</span>
            <span class="text-slate-400">
              {formatTime(new Date(e.occurred_at))} · {shortDevice(e.device_role, e.device_id)}
            </span>
          </div>
          {#if e.message}
            <div class="mt-0.5 text-sm text-rose-900">{e.message}</div>
          {/if}
          {#if e.attrs && (e.attrs as Record<string, unknown>).error}
            <pre class="mt-1 whitespace-pre-wrap text-[10px] text-rose-700">{String(
                (e.attrs as Record<string, unknown>).error,
              ).slice(0, 600)}</pre>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</section>

<section class="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
  <div class="mb-2 flex flex-wrap items-center gap-2">
    <h2 class="mr-auto text-sm font-semibold text-slate-700">イベントストリーム</h2>
    <input
      type="text"
      placeholder="kind / device で絞り込み"
      bind:value={filter}
      class="w-56 rounded-md border border-slate-300 px-2 py-1 text-xs"
    />
    <select bind:value={level} class="rounded-md border border-slate-300 px-2 py-1 text-xs">
      <option value="">すべてのレベル</option>
      <option value="error">error</option>
      <option value="warn">warn 以上</option>
      <option value="info">info 以上</option>
    </select>
    <button class="text-xs text-slate-500 hover:text-slate-800" onclick={clearEvents}>クリア</button>
  </div>
  {#if visibleEvents.length === 0}
    <div class="py-4 text-center text-sm text-slate-400">受信待ち...</div>
  {:else}
    <ul class="max-h-[28rem] space-y-0.5 overflow-y-auto font-mono text-xs">
      {#each visibleEvents as e (e.id)}
        <li class="ev-row ev-level-{e.level}">
          <span class="text-slate-400">{formatTime(new Date(e.occurred_at))}</span>
          <span class="uppercase">{e.level}</span>
          <span class="truncate" title={e.device_id ?? ''}
            >{shortDevice(e.device_role, e.device_id)}</span
          >
          <span class="truncate" title={JSON.stringify(e.attrs ?? {})}
            >{e.kind}{e.message ? ' — ' + e.message : ''}</span
          >
        </li>
      {/each}
    </ul>
  {/if}
</section>

<section class="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
  <h2 class="mb-2 text-sm font-semibold text-slate-700">イベント種別 × 端末</h2>
  <div class="overflow-x-auto">
    <table class="w-full text-xs">
      <thead class="border-b text-slate-500">
        <tr>
          <th class="py-1 pr-3 text-left">kind</th>
          <th class="px-2 py-1 text-right">合計</th>
          <th class="py-1 pl-2 text-left">端末別内訳</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-slate-100">
        {#each kindRows as r (r.kind)}
          <tr>
            <td class="py-1.5 pr-3 font-mono">{r.kind}</td>
            <td class="px-2 py-1.5 text-right tabular-nums">{r.total}</td>
            <td class="py-1.5 pl-2">
              {#each r.devices as [dev, n] (dev)}
                <span class="mr-1 mb-0.5 inline-block rounded bg-slate-100 px-1.5 py-0.5"
                  >{dev} <span class="text-slate-400">{n}</span></span
                >
              {/each}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</section>
