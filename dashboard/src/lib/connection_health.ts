// 接続情報の妥当性検証と Supabase への疎通確認。
import type { Settings } from './stores/settings';

export type HealthStatus =
  | { kind: 'idle' } // 未判定 (起動直後)
  | { kind: 'ok' }
  | { kind: 'missing' } // url / key のいずれかが空
  | { kind: 'invalid_url'; detail: string }
  | { kind: 'invalid_key'; detail: string }
  | { kind: 'unauthorized'; detail: string } // 401: key が間違っている
  | { kind: 'unreachable'; detail: string }; // ネットワーク到達不可

const URL_RE = /^https:\/\/[a-z0-9-]+\.supabase\.(co|in)\/?$/i;
// Supabase は 2 形式の publishable key を発行する:
//   - 旧 JWT 形式: eyJ で始まる base64url の 3 セグメント (例: eyJhbGc.xxx.yyy)
//   - 新 publishable 形式 (2024〜): sb_publishable_<random>
const JWT_RE = /^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;
const SB_PUBLISHABLE_RE = /^sb_publishable_[A-Za-z0-9_-]+$/;
const SB_SECRET_RE = /^sb_secret_/;

export function validateFormat(s: Settings): HealthStatus {
  if (!s.url || !s.key) return { kind: 'missing' };
  const url = s.url.trim();
  const key = s.key.trim();
  if (url !== s.url || key !== s.key) {
    return { kind: 'invalid_url', detail: 'URL または anon key に空白/改行が含まれています' };
  }
  if (!URL_RE.test(url)) {
    return {
      kind: 'invalid_url',
      detail: `URL の形式が不正です: "${url}" (期待: https://xxxx.supabase.co)`,
    };
  }
  // secret key は絶対にフロントに置かない
  if (SB_SECRET_RE.test(key)) {
    return {
      kind: 'invalid_key',
      detail:
        'secret key (sb_secret_*) が登録されています。フロントエンドには絶対に置かないでください。Project Settings → API → Publishable 側のキーを使ってください。',
    };
  }
  // 明らかにおかしい長さ (< 20 字) のみ拒否。形式判定の本質は API 側の認証に任せる。
  if (key.length < 20) {
    return {
      kind: 'invalid_key',
      detail: `anon key が短すぎます (${key.length} 字)。Supabase ダッシュボードからコピーしなおしてください。`,
    };
  }
  // 既知形式以外でも通すが、見慣れない形式の場合は console に注意を残す
  if (!JWT_RE.test(key) && !SB_PUBLISHABLE_RE.test(key)) {
    console.warn(
      `[connection_health] 既知形式 (eyJ.../sb_publishable_*) に合致しない anon key です。長さ=${key.length}、先頭=${key.slice(0, 8)}... API 側で認証検証されます。`,
    );
  }
  return { kind: 'ok' };
}

// REST ルートに HEAD を打って疎通と認証を確認する。
// 200: 正常 / 401: key 無効 / その他: 到達不可
export async function probeConnection(s: Settings, signal?: AbortSignal): Promise<HealthStatus> {
  const format = validateFormat(s);
  if (format.kind !== 'ok') return format;
  const url = `${s.url.replace(/\/$/, '')}/rest/v1/`;
  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: { apikey: s.key, Authorization: `Bearer ${s.key}` },
      signal,
    });
    if (res.status === 401 || res.status === 403) {
      return {
        kind: 'unauthorized',
        detail: `anon key が拒否されました (HTTP ${res.status})。Supabase ダッシュボードの値と一致しているか確認してください。`,
      };
    }
    if (res.status >= 500) {
      return { kind: 'unreachable', detail: `Supabase サーバーエラー (HTTP ${res.status})` };
    }
    return { kind: 'ok' };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return {
      kind: 'unreachable',
      detail: `Supabase に到達できません: ${msg} (URL のスペルを確認してください)`,
    };
  }
}

export function describe(h: HealthStatus): string {
  switch (h.kind) {
    case 'idle':
      return '接続確認中…';
    case 'ok':
      return '';
    case 'missing':
      return 'Supabase の接続情報が未設定です。';
    case 'invalid_url':
      return `URL が不正です: ${h.detail}`;
    case 'invalid_key':
      return `anon key が不正です: ${h.detail}`;
    case 'unauthorized':
      return `認証エラー: ${h.detail}`;
    case 'unreachable':
      return `接続失敗: ${h.detail}`;
  }
}

export function severity(h: HealthStatus): 'info' | 'warn' | 'error' {
  switch (h.kind) {
    case 'idle':
      return 'info';
    case 'ok':
      return 'info';
    case 'missing':
      return 'warn';
    case 'invalid_url':
    case 'invalid_key':
    case 'unauthorized':
    case 'unreachable':
      return 'error';
  }
}
