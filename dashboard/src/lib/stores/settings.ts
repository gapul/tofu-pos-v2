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

// SvelteKit では Vite 直接の import.meta.env からは PUBLIC_* を取れないため
// 必ず $env/static/public 経由で読む (ビルド時に静的置換)。
const ENV_URL = env.PUBLIC_SUPABASE_URL ?? '';
const ENV_KEY = env.PUBLIC_SUPABASE_ANON_KEY ?? '';

const defaults: Settings = { url: ENV_URL, key: ENV_KEY, shop: '' };

function load(): Settings {
  if (!browser) return { ...defaults };
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    const stored = raw ? JSON.parse(raw) : {};
    // env で URL/key が指定されていれば常にそれを優先 (デプロイ環境の安定化)
    const base: Settings = {
      url: ENV_URL || stored.url || '',
      key: ENV_KEY || stored.key || '',
      shop: stored.shop ?? '',
    };
    // ?shop=xxx で上書き可能
    const params = new URLSearchParams(location.search);
    const qShop = params.get('shop');
    if (qShop) base.shop = qShop;
    return base;
  } catch {
    return { ...defaults };
  }
}

export const hasEnvConnection = Boolean(ENV_URL && ENV_KEY);

export const settings = writable<Settings>(load());

if (browser) {
  settings.subscribe((s) => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
    } catch {
      /* noop */
    }
  });
}

export function clearSettings() {
  if (browser) localStorage.removeItem(STORAGE_KEY);
  settings.set({ ...defaults });
}

export function hasConnection(s: Settings = get(settings)): boolean {
  return Boolean(s.url && s.key);
}
