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
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-surface-inverse/50 p-4 backdrop-blur-sm">
    <div class="w-full max-w-lg space-y-5 rounded-xl border border-border-subtle bg-canvas p-6 shadow-xl">
      <div>
        <h2 class="text-h4 text-ink">接続設定</h2>
        <p class="mt-1 text-body-sm text-ink-tertiary">
          Supabase 接続情報はブラウザの localStorage に保存され、このダッシュボードからのみ参照されます。
        </p>
      </div>
      <div>
        <label class="label" for="s-url">Supabase URL</label>
        <input id="s-url" type="text" bind:value={url} placeholder="https://xxxx.supabase.co" class="input w-full" />
      </div>
      <div>
        <label class="label" for="s-key">Anon キー</label>
        <input id="s-key" type="password" bind:value={key} placeholder="eyJhbGciOiJIUzI1Ni..." class="input w-full font-mono" />
      </div>
      <div class="flex justify-end gap-2 pt-2">
        <button class="btn" onclick={clear}>削除</button>
        <button class="btn" onclick={() => (open = false)}>キャンセル</button>
        <button class="btn-primary" onclick={save}>保存</button>
      </div>
    </div>
  </div>
{/if}
