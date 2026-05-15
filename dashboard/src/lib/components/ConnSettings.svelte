<script lang="ts">
  // Supabase URL / anon key 入力モーダル。
  import { settings, clearSettings } from '../stores/settings';

  let { open = $bindable(false), onSaved }: { open?: boolean; onSaved?: () => void } = $props();

  let url = $state('');
  let key = $state('');

  $effect(() => {
    if (open) {
      url = $settings.url;
      key = $settings.key;
    }
  });

  function save() {
    settings.update((s) => ({ ...s, url: url.trim(), key: key.trim() }));
    open = false;
    onSaved?.();
  }

  function clear() {
    clearSettings();
    url = '';
    key = '';
  }
</script>

{#if open}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4">
    <div class="w-full max-w-lg space-y-4 rounded-lg bg-white p-6 shadow-xl">
      <h2 class="text-lg font-semibold">接続設定</h2>
      <p class="text-sm text-slate-500">
        Supabase 接続情報はブラウザの localStorage に保存され、このダッシュボードからのみ参照されます。
      </p>
      <div>
        <label class="mb-1 block text-xs text-slate-500" for="s-url">Supabase URL</label>
        <input
          id="s-url"
          type="text"
          bind:value={url}
          placeholder="https://xxxx.supabase.co"
          class="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
        />
      </div>
      <div>
        <label class="mb-1 block text-xs text-slate-500" for="s-key">Anon キー</label>
        <input
          id="s-key"
          type="password"
          bind:value={key}
          placeholder="eyJhbGciOiJIUzI1Ni..."
          class="w-full rounded-md border border-slate-300 px-3 py-2 font-mono text-sm"
        />
      </div>
      <div class="flex justify-end gap-2 pt-2">
        <button
          class="rounded-md bg-slate-100 px-3 py-1.5 text-sm hover:bg-slate-200"
          onclick={clear}>削除</button
        >
        <button
          class="rounded-md bg-slate-100 px-3 py-1.5 text-sm hover:bg-slate-200"
          onclick={() => (open = false)}>キャンセル</button
        >
        <button
          class="rounded-md bg-slate-900 px-4 py-1.5 text-sm text-white hover:bg-slate-700"
          onclick={save}>保存</button
        >
      </div>
    </div>
  </div>
{/if}
