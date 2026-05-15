# Tofu POS Dashboard (SvelteKit)

仕様書 §8.5 で定義する「Web 管理ページ」。読み取り専用で売上を集計表示し、
Tester タブでテレメトリイベントをリアルタイム表示する。

- フレームワーク: **SvelteKit (Svelte 5 / Runes API)**
- ビルド: `@sveltejs/adapter-static` → 静的 SPA（CF Pages 互換）
- スタイル: Tailwind CSS + PostCSS
- データ: `@supabase/supabase-js` v2（Realtime 含む）
- グラフ: Chart.js
- パッケージマネージャ: **pnpm**

> **位置づけ**: 動作確認用の暫定 UI（POS 本体の DevConsole 相当）。
> 本番 UI は Figma でデザイン確定後に差し替え予定。仕様（指標・期間フィルタ・接続情報の扱い）はそのまま継続。

## ローカル開発

```sh
cd dashboard
pnpm install
pnpm dev        # http://localhost:5173
```

主要スクリプト:

| コマンド | 内容 |
|---|---|
| `pnpm dev` | Vite dev サーバ（HMR） |
| `pnpm build` | `build/` に静的サイトを生成 |
| `pnpm preview` | `build/` をローカル配信して動作確認 |
| `pnpm check` | `svelte-check` で型チェック |

ブラウザで開いたら **⚙ 設定** から Supabase の URL と anon キーを保存
（localStorage に保存される）。店舗 ID は設定モーダル、または URL クエリ
`?shop=yakisoba_A` で指定できる。

## ディレクトリ構成

```
dashboard/
├── src/
│   ├── app.html / app.css / app.d.ts
│   ├── lib/
│   │   ├── supabase.ts          # Supabase クライアント (derived store)
│   │   ├── time.ts              # JST 時刻ヘルパ
│   │   ├── sales.ts             # order_lines 取得 + 集計
│   │   ├── stores/
│   │   │   ├── settings.ts      # localStorage 永続化
│   │   │   └── realtime.ts      # telemetry_events 購読
│   │   └── components/
│   │       ├── ConnSettings.svelte
│   │       ├── KpiCard.svelte
│   │       ├── HourlyChart.svelte
│   │       ├── CategoryChart.svelte
│   │       ├── ProductRanking.svelte
│   │       ├── AttrBreakdown.svelte
│   │       └── EventStream.svelte
│   └── routes/
│       ├── +layout.{ts,svelte}
│       ├── +page.svelte         # 売上タブ
│       └── tester/+page.svelte  # Tester タブ
├── static/
│   └── _headers                 # CF Pages 向けヘッダ
├── svelte.config.js
├── vite.config.ts
├── tailwind.config.js / postcss.config.js
└── tsconfig.json
```

## 機能

### 📈 売上タブ (`/`)

仕様書 §8.5。データソース: `public.order_lines`

- 売上合計（取消除く・按分割引差し引き後）
- 注文件数 / 取消件数 / 平均客単価 / 取消率
- 時間帯別売上（棒グラフ）
- 商品別ランキング（数量 + 売上、上位10）
- 顧客属性内訳（年代 / 性別 / 客層）
- 期間フィルタ: 本日 / 前日 / 直近7日 / 任意

### 🧪 Tester タブ (`/tester/`)

実機テスト中の telemetry をライブ表示。データソース: `public.telemetry_events`
+ Supabase Realtime (`postgres_changes`)。

- ライブステータス（直近1分 / 直近1時間エラー / アクティブ端末 / 最終受信）
- エラー専用ストリーム
- 全イベントストリーム（kind / device で検索、レベル絞り込み）
- イベント種別 × 端末の集計表

## Cloudflare Pages デプロイ

`.github/workflows/cf-pages-dashboard.yml` が `dashboard/**` の変更を検知し、
`pnpm install && pnpm build` を実行してから `dashboard/build/` を
`wrangler pages deploy` で公開する。

必要な GitHub Secrets:

- `CLOUDFLARE_API_TOKEN` — Account / Cloudflare Pages / Edit 権限
- `CLOUDFLARE_ACCOUNT_ID`

CF Pages プロジェクト名: `tofu-pos-dashboard`

`static/_headers` は adapter-static が `build/` 直下にコピーするので、
そのまま Cloudflare Pages のレスポンスヘッダとして効く。

## データソース

| タブ | テーブル | マイグレーション |
|---|---|---|
| 📈 売上 | `public.order_lines` | `supabase/migrations/0001_initial.sql` |
| 🧪 Tester | `public.telemetry_events` | `supabase/migrations/0002_telemetry.sql` |

RLS の `anon read` ポリシーに乗る。**現状は anon キー＋公開 RLS のため、
URL とキーを知る人が閲覧できる前提**。

## 不可侵範囲

このプロジェクトは Flutter 側 (`lib/`, `ios/`, `android/`, `pubspec.yaml` 等) や
`supabase/migrations/` に依存せず、これらのファイルを変更しない。
