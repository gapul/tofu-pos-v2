# Tofu POS

学園祭の模擬店向けオフライン対応 POS システム。

詳細仕様は [`仕様書.md`](./仕様書.md) を参照してください。

---

## 動作環境

- Flutter 3.38.1
- Dart 3.10.0
- iOS 12+ / Android 6.0+ (API 23+)
- Supabase（オンライン同期用、無料枠で完結）

---

## クイックスタート

### 1. 依存解決

```bash
flutter pub get
```

### 2. 環境変数の設定

`.env.example` を `.env` にコピーして値を埋める:

```bash
cp .env.example .env
```

`.env`:
```
SUPABASE_URL=https://xxxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=sb_publishable_xxxxx
```

### 3. コード生成（drift）

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. テスト実行

```bash
flutter test
```

### 5. アプリ起動（実機 or シミュレータ）

ローカル開発は `.env` の値を `--dart-define` 経由で渡すラッパー経由が必須:

```bash
tools/run-dev.sh                       # flutter run（既定）
tools/run-dev.sh -d <device-id>        # 端末指定
tools/run-dev.sh build ipa --release   # IPA を作る場合も同じ
```

**注意**: 直接 `flutter run` で起動すると `.env` の値は読み込まれず、
Supabase 接続情報なしで起動します（dotenv の asset 同梱はセキュリティ理由で廃止済み）。

起動すると **DevConsole**（仮UI）が開きます。Figma デザイン確定後に本番UIに差し替え予定。

---

## プロジェクト構造

[`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) に詳細あり。要約:

```
lib/
├── main.dart, app.dart
├── core/         横断インフラ（Transport抽象、ロギング、設定、同期、ルーティング、テーマ）
├── domain/       純Dartの業務モデル（Entity / Value Object / UseCase / Repository IF）
├── data/         Repository実装（drift / SharedPreferences / Supabase / LAN / BLE）
├── features/     画面単位の機能（dev_console, regi, kitchen, calling, settings, startup）
├── providers/    Riverpod の DI グラフ
└── ...
```

---

## Supabase セットアップ

[`supabase/README.md`](./supabase/README.md) を参照。要約:

1. Supabase ダッシュボードで SQL Editor を開く
2. `supabase/migrations/0001_initial.sql` の中身を貼り付けて Run

---

## テスト

```bash
# 全テスト
flutter test

# 特定ファイル
flutter test test/domain/usecases/checkout_usecase_test.dart

# カバレッジ
flutter test --coverage
```

現状 190 件 passing、`flutter analyze` 0 issues。

---

## ライセンス

未定（Private project）

---

## ドキュメント

- [`仕様書.md`](./仕様書.md): システム仕様書（業務 + UI/UX要件）
- [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md): アーキテクチャ詳細
- [`docs/MANUAL_TEST_RUNBOOK.md`](./docs/MANUAL_TEST_RUNBOOK.md): 実機テストのチェックリスト（Online / LAN / BLE / 学祭リハ）
- [`supabase/README.md`](./supabase/README.md): Supabase セットアップ
- [`supabase/functions/README.md`](./supabase/functions/README.md): Edge Functions
- [`dashboard/README.md`](./dashboard/README.md): 売上可視化用 Web ダッシュボード（暫定UI / Figma 待ち）
