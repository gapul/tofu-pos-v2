# Tofu POS Dashboard（暫定 UI）

仕様書 §8.5 で定義する「Web 管理ページ」。読み取り専用で売上を集計表示する。

> **位置づけ**: 現状の `index.html` は **動作確認用の暫定 UI** です（POS 本体の DevConsole 相当）。
> 本番 UI は Figma でデザイン確定後に差し替えます。仕様（指標・期間フィルタ・接続情報の扱い）はそのまま継続します。

## 構成

| ファイル | 内容 |
|---|---|
| `index.html` | エントリ。Tailwind / Supabase JS / Chart.js を CDN から読む |
| `app.js` | データ取得・集計・描画（ESM モジュール） |
| `styles.css` | 補助スタイル |

ビルドステップなし。Supabase JS と Chart.js は `index.html` の importmap で `esm.sh` から取得します。

## 使い方

1. 任意の静的サーバーで `dashboard/` を配信:
   ```bash
   cd dashboard
   python3 -m http.server 8787
   # → http://localhost:8787
   ```
2. ブラウザで開いたら **⚙ 設定** から Supabase の URL と anon キーを保存（localStorage に保存される）。
3. 店舗ID を入力して **適用**。

クエリで店舗を上書き:
```
http://localhost:8787/?shop=yakisoba_A
```

## デプロイ

`dashboard/` をそのまま静的ホスティング（GitHub Pages / Cloudflare Pages / Supabase Static Hosting 等）にアップロードすれば動きます。secret はリポジトリに含めず、ブラウザの localStorage に閲覧者が入力します。

## タブ構成

### 📈 売上タブ

仕様書 §8.5 参照。

- 売上合計（取消除く・按分割引差し引き後）
- 注文件数 / 取消件数 / 平均客単価 / 取消率
- 時間帯別売上（棒グラフ）
- 商品別ランキング（数量 + 売上、上位10）
- 顧客属性内訳（年代 / 性別 / 客層）

期間フィルタ: 本日 / 前日 / 直近7日 / 任意。

### 🧪 Tester タブ（リアルタイム）

実機テスト中、各端末から流れてくるテレメトリイベントをライブ表示します。仕様書 §11 / [`docs/MANUAL_TEST_RUNBOOK.md`](../docs/MANUAL_TEST_RUNBOOK.md) と対になる機能。

- **ライブステータス**: 直近1分のイベント数 / 直近1時間のエラー / アクティブ端末数 / 最終受信時刻
- **エラーストリーム**: `level=error` のイベントだけを赤背景で抜粋表示
- **イベントストリーム**: 全イベントの時系列ログ（kind / 端末 / 検索 / レベル絞り込み付き）
- **イベント種別 × 端末**: kind ごとの発生数を端末別に集計（多端末で何がどこから来ているかが一目でわかる）

データソースは Supabase の `public.telemetry_events` テーブル（`supabase/migrations/0002_telemetry.sql`）。Supabase Realtime の `postgres_changes` でこの shop_id の INSERT を購読します。

## データソース

| タブ | テーブル | マイグレーション |
|---|---|---|
| 📈 売上 | `public.order_lines` | `supabase/migrations/0001_initial.sql` |
| 🧪 Tester | `public.telemetry_events` | `supabase/migrations/0002_telemetry.sql` |

RLS の `anon read` ポリシーに乗ります。**現状は anon キー＋公開 RLS のため、URL とキーを知る人が閲覧できる前提**です。
