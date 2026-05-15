// 接続情報・店舗 ID を localStorage に永続化する store。
import { writable, get } from 'svelte/store';
import { browser } from '$app/environment';

const STORAGE_KEY = 'tofu-pos-dashboard.settings.v1';

export interface Settings {
  url: string;
  key: string;
  shop: string;
}

const empty: Settings = { url: '', key: '', shop: '' };

function load(): Settings {
  if (!browser) return empty;
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    const base = raw ? { ...empty, ...JSON.parse(raw) } : { ...empty };
    // ?shop=xxx で上書き可能
    const params = new URLSearchParams(location.search);
    const qShop = params.get('shop');
    if (qShop) base.shop = qShop;
    return base;
  } catch {
    return { ...empty };
  }
}

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
  settings.set({ ...empty });
}

export function hasConnection(s: Settings = get(settings)): boolean {
  return Boolean(s.url && s.key);
}
