// JST 想定の日時ヘルパ。ローカル時計が JST であることを前提とする。

export function startOfDay(d: Date): Date {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

export function addDays(d: Date, n: number): Date {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

export function isoDate(d: Date): string {
  // ローカル日付の YYYY-MM-DD（toISOString は UTC になってしまうので注意）
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

export type RangeKind = 'today' | 'yesterday' | 'last7' | 'custom';

export function resolveRange(
  kind: RangeKind,
  fromStr?: string,
  toStr?: string,
): { from: Date; to: Date } {
  const today = startOfDay(new Date());
  switch (kind) {
    case 'today':
      return { from: today, to: addDays(today, 1) };
    case 'yesterday':
      return { from: addDays(today, -1), to: today };
    case 'last7':
      return { from: addDays(today, -6), to: addDays(today, 1) };
    case 'custom': {
      const from = fromStr ? startOfDay(new Date(fromStr)) : today;
      const to = toStr ? addDays(startOfDay(new Date(toStr)), 1) : addDays(from, 1);
      return { from, to };
    }
    default:
      return { from: today, to: addDays(today, 1) };
  }
}

export function formatTime(d: Date): string {
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  const ss = String(d.getSeconds()).padStart(2, '0');
  return `${hh}:${mm}:${ss}`;
}
