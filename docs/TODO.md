# 残課題

コードベースに残っている TODO と、実機検証フェーズに残してある作業のまとめ。

最終棚卸し: 2026-05-09

---

## コード上の TODO

| ファイル:行 | 内容 | 優先度 |
|---|---|---|
| `supabase/migrations/0001_initial.sql:52` | 認証導入後、anon ロールの write 権限を shop_id 単位に絞る | 中（v2） |
| `supabase/functions/cancel-order/index.ts:48` | 取消可能期間制限・操作者認証等のビジネスルール | 中（v2） |

---

## 実機検証

手順とチェックリストは [`MANUAL_TEST_RUNBOOK.md`](./MANUAL_TEST_RUNBOOK.md) 参照。
要検証ポイントの要約:

- BLE Central（flutter_blue_plus）: スキャン・接続・write・notify、shopId ベースのフィルタ
- BLE Peripheral（bluetooth_low_energy 6.x）: iOS / Android の GATT Server
- Android 12+ permissions（`BLUETOOTH_CONNECT` 等）の実機ダイアログ
- LAN mDNS（bonsoir）: 実ネットワーク／公共 Wi-Fi の AP 分離
- WebSocket（shelf_web_socket）: iOS / Android 前面アプリの安定性
- Supabase Realtime: postgres_changes の遅延・再接続
- Supabase Auth → RLS: v2 導入時の段取り

---

## Figma 本番デザインの適用待ち

各画面は **暫定 UI で実装済み** (widget test もある)。Figma の本番デザインが
確定したら、その通りに UI を差し替える。**機能配線とドメインロジックは固まっているので、
差し替えは presentation 層のみ**。

| 画面 | 参照仕様 | 実装状態 |
|---|---|---|
| 起動シーケンス（ShopID 入力／Role 選択） | §3 | ✅ 暫定 UI |
| レジ画面: 顧客属性入力 | §6.1.1 / §9.2 | ✅ 暫定 UI |
| レジ画面: 商品選択 + カート | §6.1.2 / §9.2 | ✅ 暫定 UI + widget/golden test |
| レジ画面: 会計 | §6.1.3 / §9.3 | ✅ 暫定 UI + widget/golden test |
| レジ画面: 完了 | §6.1.4 | ✅ 暫定 UI |
| レジ: 注文履歴・取消 | §6.6 | ✅ 暫定 UI + widget test |
| レジ: 締め画面 | §6.4 | ✅ 暫定 UI + widget test |
| キッチン画面 | §6.2 / §9.4 | ✅ 暫定 UI + widget/golden test |
| 呼び出し画面 | §6.3 / §9.5 | ✅ 暫定 UI + widget test |
| 設定画面（フラグ・商品マスタ・金種管理） | §4 / §6.5 | ✅ 暫定 UI + widget test |

---

## 機能拡張アイデア（Nice-to-have）

優先度低いが、運用してみてニーズが出たら検討:

- [ ] レシート印刷（Bluetooth サーマルプリンタ連携）
- [ ] 商品画像対応（Supabase Storage）
- [ ] レジ操作の音声フィードバック
- [ ] 多言語対応（intl で en/ja 切替）
- [ ] ダークモード自動切替
- [ ] 売上ダッシュボード（Web、Supabase + 任意の BI ツール）
- [ ] 複数店舗運用（shop_id 動的切替・店舗一覧画面）
- [ ] 取消の権限ロック（管理者 PIN）
- [ ] バックグラウンドでの周期同期（workmanager）
- [ ] CSV インポート（商品マスタの一括登録）
