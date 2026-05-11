# 実機テスト ランブック

仕様書 §11（非機能要件）の実機検証手順。コードでは検証しきれない項目（BLE / mDNS / OS パーミッション / バックグラウンド挙動）を、**「○○できる／できない」を ✅ / ❌ / N/A で埋める**形式で潰していくためのチェックリスト。

順序の方針は「**信頼できる経路から順にテストする**」。Online → LAN → BLE の順が、**ハマりポイントが少ない順**。BLE は最後にすることで、それ以前のテストで切り分け済みの状態で挑める。

---

## 0. 事前準備

### 0.1. 配布の足回り

| 環境 | やること | チェック |
|---|---|---|
| iOS | Apple Developer 登録、Provisioning Profile 作成、TestFlight 内部テスト構成 | ☐ |
| Android | Google Play Console 内部テストトラック、または `flutter build apk --release` を adb push | ☐ |
| 共通 | **本番ビルドは必ず `--dart-define` で `SUPABASE_URL` / `SUPABASE_ANON_KEY` を渡す**。`.env` の assets 同梱は廃止済み（シークレット流出経路を遮断するため）。ローカル開発は `tools/run-dev.sh` 経由 | ☐ |

毎回ケーブルで `flutter run` だと運用負荷が高い。最低でも TestFlight or 内部テストトラックを通せるようにしておく。

### 0.2. テスト端末

最低構成: **iPad（レジ）+ Android タブレット（キッチン）+ Android スマホ（呼び出し）** の3台、もしくは入手できる任意の組み合わせ。**iOS↔Android のクロス通信は必ず確認する**（同 OS 同士でしか動かないバグが BLE にはよく潜む）。

| 端末 | 役割候補 | 備考 |
|---|---|---|
| iPad / iPhone（iOS 15+） | レジ・キッチン・呼び出し | Local Network 許可ダイアログが出る |
| Android タブレット（API 28+） | レジ・キッチン・呼び出し | Android 12 以降の Bluetooth permissions に注意 |
| Android スマホ（古めの端末1つ） | 呼び出し | 古い端末特有の挙動（BLE スタック差）を確認 |

### 0.3. Supabase 側の設定

- マイグレーション 4 本すべて本番プロジェクトに適用済みか
  - `0001_initial.sql`（`order_lines` テーブル + RLS + Realtime publication）
  - `0002_telemetry.sql`（`telemetry_events`）
  - `0003_idempotency_key.sql`（`order_lines.idempotency_key` + partial UNIQUE）
  - `0004_device_events.sql`（端末間シグナリング `device_events` + Realtime publication）
- Database > Replication で `order_lines` と `device_events` の Realtime を有効化済みか
- `SUPABASE_URL` / `SUPABASE_ANON_KEY` が本番の値で `--dart-define` 渡されているか

---

## 1. 単機オンライン経路（最低限の動作確認）

レジ1台のみ、Wi-Fi 接続のみ。3経路の中で **最も再現性が高い**ので、まずこれで「アプリ自体はちゃんと動く」状態を担保する。

### 1.1. 起動・初期設定

| 項目 | 期待値 | 結果 |
|---|---|---|
| 起動時に DevConsole が開く | DevConsole 仮UI が表示 | ☐ |
| 店舗ID 入力 → 永続化 | 再起動後も店舗ID が復元 | ☐ |
| 役割「レジ」選択 → 永続化 | 再起動後も役割が復元 | ☐ |
| TransportMode = `online` 選択 | DevConsole に反映 | ☐ |

### 1.2. 会計フロー

| 項目 | 期待値 | 結果 |
|---|---|---|
| 商品マスタ作成 | DevConsole の Product セクションに表示 | ☐ |
| 会計確定 | 整理券番号が発番、Order が DB に入る | ☐ |
| 整理券プールが範囲内で循環 | 99 → 1 に戻る（バッファ経過後） | ☐ |
| 在庫管理オン → 残在庫減算 | DevConsole で減算が見える | ☐ |
| 在庫0時の選択不可 | 画面で選べない／確定でエラー | ☐ |
| 金種管理オン → 金種枚数の更新 | DevConsole で枚数が動く | ☐ |
| 取消 → 在庫戻し・金種戻し・整理券返却 | 全部逆方向に戻る | ☐ |

### 1.3. クラウド同期

| 項目 | 期待値 | 結果 |
|---|---|---|
| 会計確定後、`order_lines` に行追加 | Supabase ダッシュボードで確認 | ☐ |
| 機内モード ON → 確定 → 機内モード OFF | オンライン復帰後にまとめて push | ☐ |
| 1時間以上同期失敗継続 | DevConsole に prolongedFailure 通知 | ☐ |
| 取消 → `is_cancelled=true` で再 push | クラウド側でも取消行に変わる | ☐ |
| ダッシュボード（`dashboard/`）で本日の数値が出る | KPI が反映、グラフも描画 | ☐ |

### 1.4. 営業日切替

| 項目 | 期待値 | 結果 |
|---|---|---|
| 端末日付を翌日に変更 → 起動 | 整理券プールが 1 から振り直し | ☐ |
| 前日分の使用済番号がプールに返却 | プールサイズが復元 | ☐ |
| 商品マスタ・金種・フラグは持ち越し | 維持される | ☐ |

### 1.5. オンライン経路の端末間連携（Supabase Realtime / `device_events`）

レジ + キッチン（+ 呼び出し）を **インターネット接続あり**で起動、Transport モードを `online`。
`device_events` テーブル経由で端末間シグナリングが動く。

| 項目 | 期待値 | 結果 |
|---|---|---|
| 0004 マイグレーション適用済み | `device_events` テーブル存在、Realtime publication 有効 | ☐ |
| レジで会計確定 | `device_events` に `order_submitted` が INSERT | ☐ |
| キッチンで受信 | キッチン画面に注文表示（送信から 1〜2 秒以内） | ☐ |
| キッチンで提供完了 | レジ側に `order_served` 到達、ステータス更新 | ☐ |
| レジで呼び出し転送 | 呼び出し画面に `call_number` で番号表示 | ☐ |
| レジで取消 | キッチン側に `order_cancelled` 到達、調理中なら警告 | ☐ |
| 商品マスタ編集 | キッチン側へ `product_master_update` 伝播 | ☐ |
| 自分の送信が自端末にエコーバックされない | loopback dedup が効いて二重処理しない | ☐ |
| ネット切断 → 復帰 | Realtime チャネル自動再接続、消失なし | ☐ |

レジ + キッチン（最小）、+ 呼び出し（最大）を **同じ Wi-Fi に接続**。Transport モードを `localLan`。

### 2.1. パーミッション

| OS | 項目 | 期待値 | 結果 |
|---|---|---|---|
| iOS | 初回起動時「ローカルネットワーク」ダイアログ | 許可、設定 > プライバシー で確認 | ☐ |
| Android | mDNS マルチキャスト | 特別ダイアログなし、動けば OK | ☐ |

### 2.2. mDNS 発見（bonsoir）

| 項目 | 期待値 | 結果 |
|---|---|---|
| キッチン側で LanServer 起動 | mDNS で `_tofu-pos._tcp` を advertise | ☐ |
| レジ側で LanClient が発見 | DevConsole の Transport ステータスに表示 | ☐ |
| 異なる店舗ID は無視される | shopId が違う端末は連携しない | ☐ |
| **公共 Wi-Fi で AP 分離されている** | **発見できない**（既知の制約） | ☐ |

> ⚠️ 学祭会場の Wi-Fi は AP 分離されていることが多い。事前に **モバイルルータ持参** か、テザリングを基準にすると安全。

### 2.3. WebSocket 双方向

| 項目 | 期待値 | 結果 |
|---|---|---|
| レジ → キッチン: 注文送信 | キッチン画面に表示 | ☐ |
| キッチン → レジ: 提供完了 | レジ側に到達、ステータス更新 | ☐ |
| レジ → 呼び出し: 整理券番号 | 呼び出し画面に表示 | ☐ |
| レジ → キッチン: 取消通知（調理中止） | 調理中なら警告表示 | ☐ |
| 商品マスタ全件送信（低緊急） | 編集後にキッチンに伝播 | ☐ |

### 2.4. 切断・再接続

| 項目 | 期待値 | 結果 |
|---|---|---|
| キッチン端末をスリープ → 復帰 | 自動再接続、注文受信再開 | ☐ |
| Wi-Fi を切る → 再接続 | 再発見・再接続 | ☐ |
| iOS でアプリをバックグラウンドに送る | 復帰後の挙動を確認（iOS は WebSocket が切れる場合あり） | ☐ |
| Transport タイムアウト設定が効く | 規定回数失敗で送信側にエラー表示 | ☐ |

---

## 3. BLE 経路（ハマりポイント最多）

**iOS と Android のクロス組み合わせを必ず試す**。Wi-Fi を切った状態で `bluetooth` モードに切り替えて検証。

### 3.1. パーミッション（最初の壁）

| OS | 項目 | 期待値 | 結果 |
|---|---|---|---|
| Android 12+ | `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` / `BLUETOOTH_ADVERTISE` ランタイム要求 | 初回起動時にダイアログ、許可で動作 | ☐ |
| Android 11- | `ACCESS_FINE_LOCATION` ランタイム要求 | スキャンに必要、許可で動作 | ☐ |
| iOS | NSBluetoothAlwaysUsageDescription ダイアログ | 許可で動作 | ☐ |
| iOS | NSBluetoothPeripheralUsageDescription ダイアログ | Peripheral 動作時のみ | ☐ |

### 3.2. Peripheral 動作（キッチン / 呼び出し側）

| OS | 項目 | 期待値 | 結果 |
|---|---|---|---|
| Android | GATT Server 立ち上げ | LogCat に Service 公開ログ | ☐ |
| Android | Advertise（shopId 入り） | nRF Connect 等で見える | ☐ |
| iOS | GATT Server（bluetooth_low_energy） | iOS Console で advertise を確認 | ☐ |
| iOS | バックグラウンド時の挙動 | iOS は厳しめ（advertise 制限あり） | ☐ |

### 3.3. Central 動作（レジ側、flutter_blue_plus）

| 項目 | 期待値 | 結果 |
|---|---|---|
| スキャン開始 → Peripheral 発見 | shopId 一致のみフィルタ | ☐ |
| 接続 → Service / Characteristic 発見 | UUID が `ble_uuids.dart` と一致 | ☐ |
| MTU ネゴシエーション | 大きい MTU が取れる端末／取れない端末を確認 | ☐ |
| chunk 分割 write | `ble_protocol.dart` の chunk が正しく組み立て直される | ☐ |
| notify 購読 | 提供完了通知が届く | ☐ |

### 3.4. 双方向動作（クロス OS で必ず）

| シナリオ | 期待値 | 結果 |
|---|---|---|
| iOS レジ × Android キッチン | 注文送信／提供完了通知 双方向 OK | ☐ |
| Android レジ × iOS キッチン | 同上 | ☐ |
| Android レジ × Android キッチン × Android 呼び出し（3台同時） | 全経路 OK | ☐ |
| Wi-Fi OFF + Bluetooth のみ | DevConsole の Transport モード切替で完全オフライン業務可能 | ☐ |

### 3.5. ハマりやすいポイント

- **Android 12 以降の `neverForLocation` フラグ**: AndroidManifest で設定済みだが、端末によっては Location 許可も必要なケースあり
- **iOS は Peripheral がバックグラウンドで advertise しにくい**: フォアグラウンド前提で運用する
- **MTU が小さい端末**: Android の古い端末は 23 バイト固定。chunk 分割が効くか確認
- **接続維持**: 業務時間中は切断しない設計のはずだが、実機ではタイムアウト切断が起きる場合あり

---

## 4. UI 実機確認（Figma 確定後）

UI フェーズに入ってから実施。

| 項目 | チェック |
|---|---|
| ブレークポイント切替（Mobile / Tablet / Laptop） | ☐ |
| 縦持ち／横持ち切替 | ☐ |
| Safe Area（ノッチ・ホームインジケータ） | ☐ |
| 商品ボタンのタップ精度（手袋・濡れた指） | ☐ |
| 屋外日光下での視認性（明度・コントラスト） | ☐ |
| 長時間運用での画面焼き付き対策（スクリーンセーバー、wakelock） | ☐ |

---

## 5. 学祭リハーサル（本番前）

学祭の数日前、実会場（できれば）または同じ Wi-Fi 環境で1日通しで動かす。

| 項目 | チェック |
|---|---|
| 朝の起動 → 営業日切替が効く | ☐ |
| 1時間あたり 100 注文程度の負荷で問題ないか | ☐ |
| バッテリー持ち（モバイルバッテリー必須？） | ☐ |
| Wi-Fi 不安定時の手動オフライン切替がスムーズ | ☐ |
| レジ締めで売上合計が一致する | ☐ |
| ダッシュボードでリアルタイムに数値が見える | ☐ |
| クラウド同期の積み残しがない | ☐ |

---

## 6. 結果記録の場所

各回のテスト結果は以下のいずれかで記録:
- このファイルを git で枝分かれさせて、`docs/test-results/YYYY-MM-DD.md` 等に保存
- もしくは Notion / GitHub Issues に貼り付け

**バグを見つけたら**: 即 GitHub Issue を立てて、再現手順 + OS / 端末 / OS バージョン / アプリバージョン（DevConsole の About セクションで確認）を残す。

---

## 7. 既知の未検証項目

以下は実機なしでは検証不可なので、本ランブックを通じて確認する:

- ☐ flutter_blue_plus のスキャン・接続が advertise の名前ベースで動くか
- ☐ bluetooth_low_energy 6.x の iOS 側 GATT Server 挙動
- ☐ Android 12+ permissions の実機ダイアログ
- ☐ bonsoir の mDNS が学祭会場 Wi-Fi で動くか
- ☐ shelf_web_socket サーバの安定性（iOS / Android 前面アプリ運用）
- ☐ Supabase Realtime postgres_changes の遅延・再接続
