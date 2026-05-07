# Architecture

Clean Architecture lite (3層) を採用。

## 層構造

```
┌─────────────────────────────────────────────┐
│  Presentation (UI + Notifier)               │
│  - lib/features/<feature>/presentation/     │
│  - Flutter Widget, Riverpod Notifier        │
└──────────────┬──────────────────────────────┘
               │ ref.watch / ref.read
┌──────────────▼──────────────────────────────┐
│  Domain (純Dart)                             │
│  - lib/domain/                              │
│  - Entity, Value Object, Repository IF, UseCase│
│  - Flutter依存なし、テスト最容易              │
└──────────────┬──────────────────────────────┘
               │ implements
┌──────────────▼──────────────────────────────┐
│  Data                                       │
│  - lib/data/                                │
│  - Repository実装、DataSource               │
│  - drift / SharedPreferences / Supabase /   │
│    LAN(WebSocket) / BLE                     │
└─────────────────────────────────────────────┘
```

依存方向: **Presentation → Domain ← Data**。
Domain は他の層を知らない。Data が Domain の interface を実装する。

---

## ディレクトリ詳細

### `lib/core/`
横断インフラ。

| サブディレクトリ | 役割 |
|---|---|
| `config/` | 環境変数アクセサ（`Env`） |
| `connectivity/` | ネット接続状態の監視 |
| `error/` | アプリ例外階層（`AppException` sealed） |
| `export/` | CSV出力 |
| `logging/` | `AppLogger`（logger パッケージのラッパ） |
| `router/` | go_router 設定 |
| `sync/` | クラウド同期（CloudSyncClient / SyncService / RealtimeListener） |
| `theme/` | Material 3 テーマ |
| `transport/` | 端末間通信の抽象（`Transport` IF）と実装（`Noop` / `Lan` / `Ble`） |

### `lib/domain/`
純 Dart の業務モデル。**Flutter依存なし**、ユニットテスト最容易。

| サブディレクトリ | 役割 |
|---|---|
| `entities/` | Order, Product, OrderItem, CashDrawer, OperationLog, CustomerAttributes |
| `value_objects/` | Money, Discount, TicketNumber, FeatureFlags, ShopId, Denomination, CheckoutDraft, DailySummary, HourlySalesBucket, CashCloseDifference, TicketNumberPool |
| `enums/` | OrderStatus, SyncStatus, KitchenStatus, CallingStatus, TransportMode, DeviceRole, CustomerAge/Gender/Group |
| `repositories/` | Repository インターフェース（`abstract interface class`）+ UnitOfWork |
| `usecases/` | CheckoutUseCase, CancelOrderUseCase, DailyResetUseCase, CashCloseUseCase, HourlySalesUseCase |

### `lib/data/`
Repository 実装と DataSource。

| サブディレクトリ | 役割 |
|---|---|
| `datasources/local/` | drift Database 定義 + テーブル |
| `datasources/lan/` | mDNS + WebSocket（LanProtocol / LanServer / LanClient） |
| `datasources/ble/` | BLE GATT（BleProtocol / BleCentralService / BlePeripheralService / BleUuids） |
| `repositories/` | DriftXxxRepository / SharedPrefsXxxRepository |

### `lib/features/`
画面単位。各 feature 内に必要に応じて domain / presentation を持つ。

| feature | 状態 |
|---|---|
| `dev_console/` | ✅ 仮UI、全機能の手動検証用 + 自動テストランナー |
| `regi/` | ✅ domain（会計フロー / 取消フロー / 商品マスタ配信 / 自動転送ルーター）。UI は Figma 待ち |
| `kitchen/` | ✅ domain（受信ルーター / 提供完了 / 商品マスタ取込 / アラート）。UI は Figma 待ち |
| `calling/` | ✅ domain（受信ルーター / 呼び出し取込）。UI は Figma 待ち |
| `settings/`, `startup/` | 空、UI は Figma 待ち |

### `lib/providers/`
Riverpod の DI グラフ。

| ファイル | 役割 |
|---|---|
| `database_providers.dart` | AppDatabase / SharedPreferences |
| `repository_providers.dart` | 各 Repository |
| `usecase_providers.dart` | 各 UseCase + smart transportProvider |
| `settings_providers.dart` | FeatureFlags / TransportMode の Stream |
| `connectivity_providers.dart` | ConnectivityMonitor |
| `sync_providers.dart` | CloudSyncClient / SyncService / RealtimeListener |
| `role_router_providers.dart` | 役割別ルーター（ServedToCall / KitchenIngest / CallingIngest） + RoleStarter |
| `auto_test_providers.dart` | DevConsole の自動テストシナリオランナー |

---

## 主要なフロー

### 会計確定（仕様書 §6.1）

```
[UI] CheckoutScreen.確定ボタン
   ↓ ref.read(checkoutFlowUseCaseProvider.future)
[CheckoutFlowUseCase]
   ├─ CheckoutUseCase.execute（不可分）
   │    ├─ 整理券プールから払い出し
   │    ├─ Order/OrderItem 保存（drift transaction）
   │    ├─ 在庫減算（在庫管理オン時）
   │    └─ 金種更新（金種管理オン時）
   └─ Transport.send（kitchenLink オン時）
        ↓ TransportMode で実装が変わる
        Online → Noop（SyncService が後で push）
        Lan    → LanClient.broadcast（WebSocket）
        Ble    → BleCentralService.broadcast（GATT書込）
```

### クラウド同期（仕様書 §8）

```
[起動時 / オンライン復帰時 / 5分周期]
   ↓
SyncService.runOnce
   ├─ OrderRepository.findUnsynced
   ├─ for each: CloudSyncClient.push(order)
   └─ on success: updateSyncStatus(synced)

失敗が1時間続いたら syncWarningProvider が prolongedFailure を emit
→ DevConsole / レジ画面で警告バナー表示（§8.2）
```

### 端末間連携の通信モード（仕様書 §7.1）

3つの経路を排他的に使い分ける（手動切替、auto fallback はしない）:

| モード | 送信側 | 受信側 |
|---|---|---|
| `online` | SyncService が Supabase に push | SupabaseRealtimeListener が postgres_changes 購読 |
| `localLan` | LanClient (WebSocket) | LanServer (WebSocket) |
| `bluetooth` | BleCentralService (GATT書込) | BlePeripheralService (GATT サーバ) |

`transportProvider` は `TransportMode` + `DeviceRole` を読んで適切な `Transport` 実装を返す。

---

## テスト戦略

| 層 | テストの粒度 |
|---|---|
| Domain | 純 Dart、即時実行、最も厚く書く（VO・UseCase を全カバー） |
| Data Repository | drift in-memory で実 SQL を流す統合的単体テスト |
| Provider | overrideWith で fake を差し込んで Notifier を検証 |
| Transport プロトコル | JSON / Frame の round-trip テスト（純粋） |
| Transport 実装（LAN/BLE） | **実機検証必要**、ユニットテスト不可 |
| UI | 本番UI実装後、golden + interaction test |

---

## 実装済 / 未実装の境界

### ✅ 実装済（コード単独で完結）
- 業務ロジック（Domain / UseCase）すべて
- Data Repository（drift / SharedPrefs）
- Cloud Sync（Supabase Postgres + Realtime）
- LAN Transport (mDNS + WebSocket)
- BLE Transport（Central / Peripheral）
- DevConsole 仮UI
- Provider DI グラフ
- 営業日切替・取消ログ・CSV出力・時間帯別サマリ

### ⏸️ 実装待ち（人間の作業要）
- 本番UI（Figma 確定待ち）
- iOS / Android 実機検証（特に BLE）
- Supabase RLS 本番化（Auth 導入後）
- TestFlight / Play Console 配布
