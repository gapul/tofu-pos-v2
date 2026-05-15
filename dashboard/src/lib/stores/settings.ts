// 接続情報・店舗 ID を localStorage に永続化する store。
import { writable, get } from 'svelte/store';
import { browser } from '$app/environment';
import { env } from '$env/dynamic/public';

const STORAGE_KEY = 'tofu-pos-dashboard.settings.v1';

export interface Settings {
  url: string;
  key: string;
  shop: string;
}

// env は SvelteKit が _app/env.js を非同期ロードして globalThis に流し込む。
// モジュール初期化時には未注入の可能性があるため、必ず関数内で都度読む。
// 関数経由ならバンドラが値を固定化せず、アクセス毎に最新を取れる。
function readEnv(): { url: string; key: string } {
  return {
    url: (env.PUBLIC_SUPABASE_URL ?? '') as string,
    key: (env.PUBLIC_SUPABASE_ANON_KEY ?? '') as string,
  };
}

export function hasEnvConnection(): boolean {
  const { url, key } = readEnv();
  return Boolean(url && key);
}

function load(): Settings {
  const e = readEnv();
  if (!browser) return { url: e.url, key: e.key, shop: '' };
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    const stored = raw ? JSON.parse(raw) : {};
    const base: Settings = {
      url: e.url || stored.url || '',
      key: e.key || stored.key || '',
      shop: stored.shop ?? '',
    };
    const qShop = new URLSearchParams(location.search).get('shop');
    if (qShop) base.shop = qShop;
    return base;
  } catch {
    return { url: e.url, key: e.key, shop: '' };
  }
}

export const settings = writable<Settings>(load());

// env のロードがモジュール初期化より遅いケースに備えて、env を再読し
// 値が手に入ったら store を上書きする。
export function refreshFromEnv(): void {
  if (!browser) return;
  const e = readEnv();
  if (!e.url || !e.key) return;
  settings.update((s) => ({
    ...s,
    url: e.url,
    key: e.key,
  }));
}

if (browser) {
  settings.subscribe((s) => {
    // url/key/shop のいずれも空なら書き込まない (初期化レースで空書きするのを防ぐ)
    if (!s.url && !s.key && !s.shop) return;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
    } catch {
      /* noop */
    }
  });
}

export function clearSettings() {
  if (browser) localStorage.removeItem(STORAGE_KEY);
  const e = readEnv();
  settings.set({ url: e.url, key: e.key, shop: '' });
}

export function hasConnection(s: Settings = get(settings)): boolean {
  return Boolean(s.url && s.key);
}
