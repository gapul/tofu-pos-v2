// telemetry_events のリアルタイム購読を司る store。
// 売上タブとは独立に動くようにし、shop_id/接続情報変更に追従する。
import { writable, get, derived } from 'svelte/store';
import type { RealtimeChannel, SupabaseClient } from '@supabase/supabase-js';
import { supabaseClient } from '../supabase';
import { settings } from './settings';

export interface TelemetryEvent {
  id: string;
  occurred_at: string;
  shop_id: string;
  device_id: string | null;
  device_role: string | null;
  scenario_id: string | null;
  level: 'debug' | 'info' | 'warn' | 'error' | string;
  kind: string;
  message: string | null;
  attrs: Record<string, unknown> | null;
}

export type LiveStatus = 'idle' | 'connecting' | 'live' | 'closed' | 'error';

const MAX_EVENTS = 500;
const MAX_ERRORS = 100;

export const events = writable<TelemetryEvent[]>([]);
export const errors = writable<TelemetryEvent[]>([]);
export const liveStatus = writable<LiveStatus>('idle');

let currentChannel: RealtimeChannel | null = null;
let currentClient: SupabaseClient | null = null;
let currentShop = '';

async function teardown() {
  if (currentChannel && currentClient) {
    try {
      await currentClient.removeChannel(currentChannel);
    } catch {
      /* noop */
    }
  }
  currentChannel = null;
}

async function setup(client: SupabaseClient, shop: string) {
  await teardown();
  currentClient = client;
  currentShop = shop;
  liveStatus.set('connecting');

  // 履歴ロード
  try {
    const { data, error } = await client
      .from('telemetry_events')
      .select('id,occurred_at,shop_id,device_id,device_role,scenario_id,level,kind,message,attrs')
      .eq('shop_id', shop)
      .order('occurred_at', { ascending: false })
      .limit(MAX_EVENTS);
    if (error) throw error;
    const list = (data ?? []) as TelemetryEvent[];
    events.set(list);
    errors.set(list.filter((e) => e.level === 'error').slice(0, MAX_ERRORS));
  } catch (e) {
    console.error('telemetry history load failed', e);
  }

  currentChannel = client
    .channel(`telemetry-${shop}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'telemetry_events',
        filter: `shop_id=eq.${shop}`,
      },
      (payload) => {
        const row = payload.new as TelemetryEvent;
        events.update((arr) => {
          const next = [row, ...arr];
          if (next.length > MAX_EVENTS) next.length = MAX_EVENTS;
          return next;
        });
        if (row.level === 'error') {
          errors.update((arr) => {
            const next = [row, ...arr];
            if (next.length > MAX_ERRORS) next.length = MAX_ERRORS;
            return next;
          });
        }
      },
    )
    .subscribe((status) => {
      if (status === 'SUBSCRIBED') liveStatus.set('live');
      else if (status === 'CLOSED') liveStatus.set('closed');
      else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') liveStatus.set('error');
    });
}

// 接続情報・店舗 ID の変化に応じて自動セットアップ
export const realtimeWatcher = derived(
  [supabaseClient, settings],
  ([$client, $s]) => ({ client: $client, shop: $s.shop }),
);

let started = false;
export function startRealtime() {
  if (started) return;
  started = true;
  realtimeWatcher.subscribe(async ({ client, shop }) => {
    if (!client || !shop) {
      await teardown();
      liveStatus.set('idle');
      return;
    }
    if (client === currentClient && shop === currentShop && currentChannel) return;
    await setup(client, shop);
  });
}

export function clearEvents() {
  events.set([]);
}
export function clearErrors() {
  errors.set([]);
}

export function shortDevice(role: string | null, deviceId: string | null): string {
  const id = (deviceId ?? '').slice(0, 8);
  return role ? `${role}/${id}` : id;
}

const order: Record<string, number> = { debug: 0, info: 1, warn: 2, error: 3 };
export function levelMatches(rowLevel: string, want: string): boolean {
  if (!want) return true;
  return (order[rowLevel] ?? 0) >= (order[want] ?? 0);
}

export { get };
