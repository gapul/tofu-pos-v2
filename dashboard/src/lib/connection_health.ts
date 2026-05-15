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

// Supabase へ疎通と認証を確認する。
// 新 publishable key は /rest/v1/ ルートを叩けない (Secret API key required)
// 仕様のため、まず /auth/v1/health で URL 自体の到達性を確認し、
// key 検証は /rest/v1/<table> を limit=0 で叩いてみる。
export async function probeConnection(s: Settings, signal?: AbortSignal): Promise<HealthStatus> {
  const format = validateFormat(s);
  if (format.kind !== 'ok') return format;
  const base = s.url.replace(/\/$/, '');

  // Step 1: URL 到達性 (auth health は認証不要 / publishable / JWT どちらでも参照可)
  try {
    const health = await fetch(`${base}/auth/v1/health`, { method: 'GET', signal });
    if (health.status >= 500) {
      return { kind: 'unreachable', detail: `Supabase 側のサーバーエラー (HTTP ${health.status})` };
    }
    if (health.status === 404) {
      return {
        kind: 'unreachable',
        detail: `${base} は Supabase プロジェクトとして応答していません (HTTP 404)。URL のスペルを確認してください。`,
      };
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return {
      kind: 'unreachable',
      detail: `Supabase に到達できません: ${msg} (URL のスペル / プロジェクト稼働状態を確認してください)`,
    };
  }

  // Step 2: key 検証。アプリが実際に読む order_lines テーブルを limit=0 で叩く。
  //   200/206: 読める (ok)
  //   401:     key 自体が無効 / 別プロジェクトの key
  //   403:     RLS で拒否 (key は OK だがポリシー次第。バナーには出さない方が無難)
  //   404:     テーブル未作成 → スキーマ未デプロイの可能性
  try {
    const probe = await fetch(`${base}/rest/v1/order_lines?select=id&limit=0`, {
      method: 'GET',
      headers: { apikey: s.key, Authorization: `Bearer ${s.key}` },
      signal,
    });
    if (probe.status === 200 || probe.status === 206 || probe.status === 403) {
      // 403 (RLS) は key 自体は正しいので OK 扱い (アプリの実クエリで再評価)
      return { kind: 'ok' };
    }
    if (probe.status === 401) {
      const body = await probe.text().catch(() => '');
      // 新 publishable で /rest/v1/ ルートを誤って叩いた等の "Secret API key required"
      // は到達性の証左なので OK 扱い (本来 /rest/v1/<table> は publishable で通る)
      if (/Secret API key required/i.test(body)) {
        return { kind: 'ok' };
      }
      return {
        kind: 'unauthorized',
        detail: `anon key が拒否されました (HTTP 401)。Supabase ダッシュボード → Project Settings → API Keys の Publishable を再コピーして登録しなおしてください。`,
      };
    }
    if (probe.status === 404) {
      return {
        kind: 'unreachable',
        detail:
          'テーブル "order_lines" が見つかりません (HTTP 404)。Supabase 側のスキーママイグレーション未適用の可能性があります。',
      };
    }
    return {
      kind: 'unreachable',
      detail: `予期せぬレスポンス HTTP ${probe.status}`,
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return {
      kind: 'unreachable',
      detail: `Supabase REST に到達できません: ${msg}`,
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
