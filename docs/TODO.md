# 残課題

コードベースに残っている TODO と、実機検証フェーズに残してある作業のまとめ。

最終棚卸し: 2026-05-07

---

## コード上の TODO

| ファイル:行 | 内容 | 優先度 |
|---|---|---|
| `supabase/migrations/0001_initial.sql:52` | 認証導入後、anon ロールの write 権限を shop_id 単位に絞る | 中（v2） |
| `supabase/functions/cancel-order/index.ts:48` | 取消可能期間制限・操作者認証等のビジネスルール | 中（v2） |

---

## 実機検証が必要な箇所

| 領域 | 内容 |
|---|---|
| **BLE Central（レジ）** | flutter_blue_plus でスキャン・接続・書き込み・notify購読が実機で正しく動くか。advName ベースの shopId フィルタが実 advertisement 仕様に合うか |
| **BLE Peripheral (iOS)** | bluetooth_low_energy 6.x の iOS 側 GATT Server が期待通り advertise / write 受信 / notify 配信できるか |
| **BLE Peripheral (Android)** | 同上、Android 12+ permission（BLUETOOTH_CONNECT 等）の挙動 |
| **LAN mDNS** | bonsoir でのサービス発見が実ネットワークで動くか。AP 分離されたネットワーク（一部の公共 Wi-Fi）での挙動 |
| **WebSocket** | shelf_web_socket サーバが iOS / Android の前面アプリで安定動作するか |
| **Supabase Realtime** | postgres_changes 購読の遅延・再接続 |
| **Supabase Auth → RLS** | v2 で導入する際の段取り |

---

## Figma デザイン待ち

UI 全般は Figma 確定後に着手。

| 画面 | 参照仕様 |
|---|---|
| 起動シーケンス（ShopID 入力／Role 選択） | §3 |
| レジ画面: 顧客属性入力 | §6.1.1 / §9.2 |
| レジ画面: 商品選択 + カート | §6.1.2 / §9.2 |
| レジ画面: 会計 | §6.1.3 / §9.3 |
| レジ画面: 完了 | §6.1.4 |
| レジ: 注文履歴・取消 | §6.6 |
| レジ: 締め画面 | §6.4 |
| キッチン画面 | §6.2 / §9.4 |
| 呼び出し画面 | §6.3 / §9.5 |
| 設定画面（フラグ・商品マスタ・金種管理） | §4 / §6.5 |

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
