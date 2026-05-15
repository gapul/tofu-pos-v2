// settings store の変更に追従して Supabase クライアントを差し替える。
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { derived } from 'svelte/store';
import { settings } from './stores/settings';

export const supabaseClient = derived<typeof settings, SupabaseClient | null>(
  settings,
  ($s, set) => {
    if (!$s.url || !$s.key) {
      set(null);
      return;
    }
    set(createClient($s.url, $s.key, { auth: { persistSession: false } }));
  },
  null,
);
