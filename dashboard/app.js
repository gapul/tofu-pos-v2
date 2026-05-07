// Tofu POS Dashboard - 読み取り専用の売上集計画面。
// データソース: Supabase の order_lines テーブル。
// 仕様書 §8.5 を参照。

import { createClient } from '@supabase/supabase-js';
import Chart from 'chart.js/auto';

// -------------------------------------------------------------------------- //
// 設定の永続化
// -------------------------------------------------------------------------- //

const STORAGE_KEY = 'tofu-pos-dashboard.settings.v1';

function loadSettings() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { url: '', key: '', shop: '' };
    return { url: '', key: '', shop: '', ...JSON.parse(raw) };
  } catch {
    return { url: '', key: '', shop: '' };
  }
}

function saveSettings(s) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
}

// クエリで店舗を上書き可能 (?shop=xxx)
const params = new URLSearchParams(location.search);
const settings = loadSettings();
if (params.get('shop')) settings.shop = params.get('shop');

// -------------------------------------------------------------------------- //
// Supabase クライアント
// -------------------------------------------------------------------------- //

let supabase = null;
function ensureClient() {
  if (!settings.url || !settings.key) {
    supabase = null;
    return false;
  }
  supabase = createClient(settings.url, settings.key, {
    auth: { persistSession: false },
  });
  return true;
}

// -------------------------------------------------------------------------- //
// 期間
// -------------------------------------------------------------------------- //

function startOfDay(d) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

function addDays(d, n) {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

function isoDate(d) {
  return d.toISOString().slice(0, 10);
}

function resolveRange(kind, fromStr, toStr) {
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

// -------------------------------------------------------------------------- //
// データ取得 + 集計
// -------------------------------------------------------------------------- //

async function fetchLines({ shop, from, to }) {
  const { data, error } = await supabase
    .from('order_lines')
    .select(
      'shop_id,local_order_id,line_no,ticket_number,customer_age,customer_gender,customer_group,order_created_at,order_status,is_cancelled,product_id,product_name,quantity,price_at_time_yen,total_item_price_yen,discount_per_item_yen',
    )
    .eq('shop_id', shop)
    .gte('order_created_at', from.toISOString())
    .lt('order_created_at', to.toISOString())
    .order('order_created_at', { ascending: true })
    .limit(50000);

  if (error) throw error;
  return data ?? [];
}

function aggregate(lines) {
  let revenue = 0;
  const orderIds = new Set();
  const cancelOrderIds = new Set();
  const productTotals = new Map(); // name -> { qty, revenue }
  const hourlyRevenue = new Array(24).fill(0);
  const ageCount = new Map();
  const genderCount = new Map();
  const groupCount = new Map();
  const orderAttrs = new Map(); // local_order_id -> {age,gender,group}

  for (const r of lines) {
    const orderKey = r.local_order_id;
    if (r.is_cancelled || r.order_status === 'cancelled') {
      cancelOrderIds.add(orderKey);
      continue;
    }
    orderIds.add(orderKey);

    const lineNet = (r.total_item_price_yen ?? 0) - (r.discount_per_item_yen ?? 0);
    revenue += lineNet;

    const p = productTotals.get(r.product_name) ?? { qty: 0, revenue: 0 };
    p.qty += r.quantity ?? 0;
    p.revenue += lineNet;
    productTotals.set(r.product_name, p);

    const hour = new Date(r.order_created_at).getHours();
    hourlyRevenue[hour] += lineNet;

    if (!orderAttrs.has(orderKey)) {
      orderAttrs.set(orderKey, {
        age: r.customer_age,
        gender: r.customer_gender,
        group: r.customer_group,
      });
    }
  }

  for (const a of orderAttrs.values()) {
    bump(ageCount, a.age);
    bump(genderCount, a.gender);
    bump(groupCount, a.group);
  }

  const productRanking = [...productTotals.entries()]
    .map(([name, v]) => ({ name, ...v }))
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 10);

  return {
    revenue,
    orderCount: orderIds.size,
    cancelCount: cancelOrderIds.size,
    productRanking,
    hourlyRevenue,
    ageCount,
    genderCount,
    groupCount,
  };
}

function bump(m, key) {
  const k = key && key.length > 0 ? key : '未取得';
  m.set(k, (m.get(k) ?? 0) + 1);
}

// -------------------------------------------------------------------------- //
// レンダリング
// -------------------------------------------------------------------------- //

const yen = (n) => '¥' + Math.round(n).toLocaleString('ja-JP');

function renderKpis(agg) {
  document.getElementById('kpi-revenue').textContent = yen(agg.revenue);
  document.getElementById('kpi-orders').textContent = agg.orderCount.toLocaleString('ja-JP');
  const avg = agg.orderCount > 0 ? agg.revenue / agg.orderCount : 0;
  document.getElementById('kpi-avg').textContent = yen(avg);
  document.getElementById('kpi-cancel').textContent = agg.cancelCount.toLocaleString('ja-JP');

  const total = agg.orderCount + agg.cancelCount;
  document.getElementById('kpi-revenue-sub').textContent = `売上対象 ${agg.orderCount} 件`;
  document.getElementById('kpi-orders-sub').textContent = `取消除く`;
  document.getElementById('kpi-cancel-sub').textContent =
    total > 0 ? `取消率 ${((agg.cancelCount / total) * 100).toFixed(1)}%` : '-';
}

function renderProductTable(rows) {
  const tbody = document.getElementById('tbl-products');
  const empty = document.getElementById('tbl-products-empty');
  tbody.innerHTML = '';
  if (rows.length === 0) {
    empty.classList.remove('hidden');
    return;
  }
  empty.classList.add('hidden');
  rows.forEach((r, i) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="py-1.5 text-slate-400">${i + 1}</td>
      <td class="py-1.5 truncate max-w-[200px]">${escapeHtml(r.name)}</td>
      <td class="py-1.5 text-right tabular-nums">${r.qty.toLocaleString('ja-JP')}</td>
      <td class="py-1.5 text-right tabular-nums">${yen(r.revenue)}</td>
    `;
    tbody.appendChild(tr);
  });
}

function escapeHtml(s) {
  return String(s ?? '').replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]),
  );
}

// 既存の Chart インスタンスを保持して、再描画時に破棄する
const charts = {};

function renderHourlyChart(hourly) {
  const ctx = document.getElementById('chart-hourly');
  charts.hourly?.destroy();
  charts.hourly = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: Array.from({ length: 24 }, (_, h) => `${h}時`),
      datasets: [
        {
          label: '売上',
          data: hourly,
          backgroundColor: 'rgba(15, 23, 42, 0.85)',
          borderRadius: 4,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        y: {
          beginAtZero: true,
          ticks: { callback: (v) => '¥' + v.toLocaleString('ja-JP') },
        },
      },
    },
  });
}

function renderCategoryChart(canvasId, key, map) {
  const ctx = document.getElementById(canvasId);
  charts[key]?.destroy();
  const entries = [...map.entries()].sort((a, b) => b[1] - a[1]);
  charts[key] = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: entries.map(([k]) => k),
      datasets: [
        {
          label: '注文数',
          data: entries.map(([, v]) => v),
          backgroundColor: 'rgba(56, 189, 248, 0.85)',
          borderRadius: 4,
        },
      ],
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: { x: { beginAtZero: true, ticks: { precision: 0 } } },
    },
  });
}

function renderAggregate(agg) {
  renderKpis(agg);
  renderProductTable(agg.productRanking);
  renderHourlyChart(agg.hourlyRevenue);
  renderCategoryChart('chart-age', 'age', agg.ageCount);
  renderCategoryChart('chart-gender', 'gender', agg.genderCount);
  renderCategoryChart('chart-group', 'group', agg.groupCount);
}

// -------------------------------------------------------------------------- //
// 制御
// -------------------------------------------------------------------------- //

function showError(msg) {
  const el = document.getElementById('error-banner');
  if (!msg) {
    el.classList.add('hidden');
    el.textContent = '';
    return;
  }
  el.textContent = msg;
  el.classList.remove('hidden');
}

function showConnectionBanner(show) {
  document.getElementById('conn-banner').classList.toggle('hidden', !show);
}

async function reload() {
  showError(null);
  if (!ensureClient()) {
    showConnectionBanner(true);
    return;
  }
  showConnectionBanner(false);

  const shop = document.getElementById('f-shop').value.trim();
  if (!shop) {
    showError('店舗IDを入力してください。');
    return;
  }

  const range = document.getElementById('f-range').value;
  const fromStr = document.getElementById('f-from').value;
  const toStr = document.getElementById('f-to').value;
  const { from, to } = resolveRange(range, fromStr, toStr);

  try {
    const lines = await fetchLines({ shop, from, to });
    const agg = aggregate(lines);
    renderAggregate(agg);
    document.getElementById('last-updated').textContent =
      `更新: ${new Date().toLocaleTimeString('ja-JP')} / ${lines.length} 行`;
  } catch (e) {
    console.error(e);
    showError(`取得に失敗しました: ${e.message ?? e}`);
  }
}

// -------------------------------------------------------------------------- //
// イベント配線
// -------------------------------------------------------------------------- //

function init() {
  document.getElementById('f-shop').value = settings.shop ?? '';
  document.getElementById('f-from').value = isoDate(addDays(startOfDay(new Date()), -6));
  document.getElementById('f-to').value = isoDate(startOfDay(new Date()));

  document.getElementById('f-range').addEventListener('change', (e) => {
    document.getElementById('f-custom').classList.toggle('hidden', e.target.value !== 'custom');
  });

  document.getElementById('btn-apply').addEventListener('click', () => {
    settings.shop = document.getElementById('f-shop').value.trim();
    saveSettings(settings);
    reload();
    startTester();
  });

  document.getElementById('btn-reload').addEventListener('click', reload);

  // 設定モーダル
  const modal = document.getElementById('settings-modal');
  const open = () => {
    document.getElementById('s-url').value = settings.url ?? '';
    document.getElementById('s-key').value = settings.key ?? '';
    modal.classList.remove('hidden');
  };
  const close = () => modal.classList.add('hidden');
  document.getElementById('btn-settings').addEventListener('click', open);
  document.getElementById('s-cancel').addEventListener('click', close);
  document.getElementById('s-save').addEventListener('click', () => {
    settings.url = document.getElementById('s-url').value.trim();
    settings.key = document.getElementById('s-key').value.trim();
    saveSettings(settings);
    close();
    reload();
    startTester();
  });
  document.getElementById('s-clear').addEventListener('click', () => {
    localStorage.removeItem(STORAGE_KEY);
    settings.url = '';
    settings.key = '';
    document.getElementById('s-url').value = '';
    document.getElementById('s-key').value = '';
  });

  // タブ切替
  initTabs();
  initTester();

  // 初回ロード: 設定済みなら即座に取りに行く
  if (settings.url && settings.key && settings.shop) {
    reload();
    startTester();
  } else {
    showConnectionBanner(!settings.url || !settings.key);
  }
}

function initTester() {
  const evFilter = document.getElementById('ev-filter');
  const evLevel = document.getElementById('ev-level');
  evFilter.addEventListener('input', (e) => {
    tester.filter = e.target.value;
    renderEventStream();
  });
  evLevel.addEventListener('change', (e) => {
    tester.level = e.target.value;
    renderEventStream();
  });
  document.getElementById('btn-clear-events').addEventListener('click', () => {
    tester.events = [];
    renderTester();
  });
  document.getElementById('btn-clear-errors').addEventListener('click', () => {
    tester.errors = [];
    renderTester();
  });
}

// -------------------------------------------------------------------------- //
// タブ切替
// -------------------------------------------------------------------------- //

function initTabs() {
  const buttons = document.querySelectorAll('.tab-btn');
  const panes = document.querySelectorAll('.tab-pane');
  buttons.forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.tab === 'sales');
    btn.addEventListener('click', () => {
      buttons.forEach((b) => b.classList.toggle('active', b === btn));
      const target = btn.dataset.tab;
      panes.forEach((p) => p.classList.toggle('hidden', p.id !== `tab-${target}`));
    });
  });
}

// -------------------------------------------------------------------------- //
// Tester（リアルタイム）
// -------------------------------------------------------------------------- //
// telemetry_events テーブルを購読し、入ってきたイベントを画面に流す。

const TESTER_MAX_EVENTS = 500;
const TESTER_MAX_ERRORS = 100;
const tester = {
  channel: null,
  events: [], // 新しいものが先頭
  errors: [],
  filter: '',
  level: '',
  recentTimer: null,
};

async function startTester() {
  if (!supabase || !settings.shop) return;
  // 既存チャンネルがあれば張り替え
  if (tester.channel) {
    await supabase.removeChannel(tester.channel);
    tester.channel = null;
  }

  // 直近の履歴を取り込み（再読み込み時に空白にしない）
  await loadTesterHistory();

  // Realtime 購読
  tester.channel = supabase
    .channel(`telemetry-${settings.shop}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'telemetry_events',
        filter: `shop_id=eq.${settings.shop}`,
      },
      (payload) => onIncoming(payload.new),
    )
    .subscribe((status) => {
      const dot = document.getElementById('live-dot');
      const label = document.getElementById('live-status');
      if (status === 'SUBSCRIBED') {
        dot.classList.add('live');
        label.textContent = 'ライブ受信中';
      } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        dot.classList.remove('live');
        label.textContent = `切断 (${status})`;
      }
    });

  // 直近1分のイベント数の更新
  if (!tester.recentTimer) {
    tester.recentTimer = setInterval(updateAggregates, 1000);
  }
}

async function loadTesterHistory() {
  try {
    const { data, error } = await supabase
      .from('telemetry_events')
      .select('id,occurred_at,shop_id,device_id,device_role,scenario_id,level,kind,message,attrs')
      .eq('shop_id', settings.shop)
      .order('occurred_at', { ascending: false })
      .limit(TESTER_MAX_EVENTS);
    if (error) throw error;
    tester.events = data ?? [];
    tester.errors = tester.events.filter((e) => e.level === 'error').slice(0, TESTER_MAX_ERRORS);
    renderTester();
  } catch (e) {
    console.error('history load failed', e);
  }
}

function onIncoming(row) {
  tester.events.unshift(row);
  if (tester.events.length > TESTER_MAX_EVENTS) tester.events.length = TESTER_MAX_EVENTS;
  if (row.level === 'error') {
    tester.errors.unshift(row);
    if (tester.errors.length > TESTER_MAX_ERRORS) tester.errors.length = TESTER_MAX_ERRORS;
  }
  renderTester();
}

function renderTester() {
  renderEventStream();
  renderErrorStream();
  renderKindTable();
  updateAggregates();
}

function levelMatches(rowLevel, want) {
  if (!want) return true;
  const order = { debug: 0, info: 1, warn: 2, error: 3 };
  return (order[rowLevel] ?? 0) >= (order[want] ?? 0);
}

function rowMatchesFilter(row) {
  if (tester.level && !levelMatches(row.level, tester.level)) return false;
  if (!tester.filter) return true;
  const f = tester.filter.toLowerCase();
  return (
    (row.kind ?? '').toLowerCase().includes(f) ||
    (row.device_id ?? '').toLowerCase().includes(f) ||
    (row.device_role ?? '').toLowerCase().includes(f) ||
    (row.message ?? '').toLowerCase().includes(f)
  );
}

function renderEventStream() {
  const ul = document.getElementById('ev-stream');
  const empty = document.getElementById('ev-empty');
  ul.innerHTML = '';
  const visible = tester.events.filter(rowMatchesFilter);
  if (visible.length === 0) {
    empty.classList.remove('hidden');
    return;
  }
  empty.classList.add('hidden');
  for (const e of visible.slice(0, 200)) {
    const li = document.createElement('li');
    li.className = `ev-row ev-level-${e.level}`;
    const t = new Date(e.occurred_at);
    li.innerHTML = `
      <span class="text-slate-400">${formatTime(t)}</span>
      <span class="uppercase">${e.level}</span>
      <span class="truncate" title="${escapeHtml(e.device_id ?? '')}">${escapeHtml(shortDevice(e.device_role, e.device_id))}</span>
      <span class="truncate" title="${escapeHtml(JSON.stringify(e.attrs ?? {}))}">${escapeHtml(e.kind)}${e.message ? ' — ' + escapeHtml(e.message) : ''}</span>
    `;
    ul.appendChild(li);
  }
}

function renderErrorStream() {
  const ul = document.getElementById('err-stream');
  const empty = document.getElementById('err-empty');
  ul.innerHTML = '';
  if (tester.errors.length === 0) {
    empty.classList.remove('hidden');
    return;
  }
  empty.classList.add('hidden');
  for (const e of tester.errors.slice(0, 50)) {
    const li = document.createElement('li');
    li.className = 'rounded border border-rose-100 bg-rose-50/50 px-3 py-2';
    const t = new Date(e.occurred_at);
    li.innerHTML = `
      <div class="flex items-center justify-between text-xs text-rose-700">
        <span class="font-mono">${escapeHtml(e.kind)}</span>
        <span class="text-slate-400">${formatTime(t)} · ${escapeHtml(shortDevice(e.device_role, e.device_id))}</span>
      </div>
      ${e.message ? `<div class="mt-0.5 text-sm text-rose-900">${escapeHtml(e.message)}</div>` : ''}
      ${e.attrs && e.attrs.error ? `<pre class="mt-1 text-[10px] text-rose-700 whitespace-pre-wrap">${escapeHtml(String(e.attrs.error).slice(0, 600))}</pre>` : ''}
    `;
    ul.appendChild(li);
  }
}

function renderKindTable() {
  const tbody = document.getElementById('kind-table');
  tbody.innerHTML = '';
  // kind ごと: 合計 + 端末別
  const byKind = new Map();
  for (const e of tester.events) {
    const k = e.kind;
    if (!byKind.has(k)) byKind.set(k, { total: 0, byDevice: new Map() });
    const slot = byKind.get(k);
    slot.total++;
    const dev = shortDevice(e.device_role, e.device_id);
    slot.byDevice.set(dev, (slot.byDevice.get(dev) ?? 0) + 1);
  }
  const rows = [...byKind.entries()].sort((a, b) => b[1].total - a[1].total);
  for (const [kind, agg] of rows.slice(0, 30)) {
    const tr = document.createElement('tr');
    const breakdown = [...agg.byDevice.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([d, n]) => `<span class="inline-block bg-slate-100 rounded px-1.5 py-0.5 mr-1 mb-0.5">${escapeHtml(d)} <span class="text-slate-400">${n}</span></span>`)
      .join('');
    tr.innerHTML = `
      <td class="py-1.5 pr-3 font-mono">${escapeHtml(kind)}</td>
      <td class="py-1.5 px-2 text-right tabular-nums">${agg.total}</td>
      <td class="py-1.5 pl-2">${breakdown}</td>
    `;
    tbody.appendChild(tr);
  }
}

function updateAggregates() {
  const oneMinAgo = Date.now() - 60 * 1000;
  const oneHourAgo = Date.now() - 60 * 60 * 1000;
  const recent = tester.events.filter((e) => new Date(e.occurred_at).getTime() >= oneMinAgo).length;
  const errors1h = tester.errors.filter((e) => new Date(e.occurred_at).getTime() >= oneHourAgo).length;
  const devices = new Set(tester.events.map((e) => e.device_id)).size;
  document.getElementById('live-recent').textContent = recent.toLocaleString('ja-JP');
  document.getElementById('live-error').textContent = errors1h.toLocaleString('ja-JP');
  document.getElementById('live-devices').textContent = devices.toLocaleString('ja-JP');
  document.getElementById('live-last').textContent = tester.events[0]
    ? formatTime(new Date(tester.events[0].occurred_at))
    : '-';
}

function shortDevice(role, deviceId) {
  const id = (deviceId ?? '').slice(0, 8);
  return role ? `${role}/${id}` : id;
}

function formatTime(d) {
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  const ss = String(d.getSeconds()).padStart(2, '0');
  return `${hh}:${mm}:${ss}`;
}

init();
