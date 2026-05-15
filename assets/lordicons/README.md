# Lordicons

このディレクトリには Lordicon の Lottie JSON (`*.json`) を配置する。

## ライセンス

Icons by [Lordicon](https://lordicon.com), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

クレジット表記は `LICENSE` および本ファイルで行う。アプリ内クレジット
画面 (設定 > このアプリについて) でも表示すること。

## 取得手順

Phase 1 で使用する 10 個のアイコンを Lordicon Free (System Regular) から
ダウンロードして本ディレクトリに配置する。

ファイル名 → Lordicon 上での参照名 (System Regular):

| ファイル名 | 用途 |
| --- | --- |
| `trash.json` | カート全削除 |
| `check.json` | 会計確定 / 提供完了 |
| `arrow-right.json` | 次のお客様 |
| `settings.json` | 設定アイコン |
| `bell.json` | 呼び出し |
| `chef-hat.json` | 調理 (将来) |
| `clock.json` | 経過時間 (将来) |
| `alert.json` | 警告 (将来) |
| `info.json` | 案内 (将来) |
| `cart.json` | 会計へ進む (将来) |

### 取得方法

1. https://lordicon.com/icons にアクセスし、各アイコンを開く。
2. Style を **System / Regular** に設定 (Free ライセンスの範囲)。
3. 「Download → Lottie (.json)」を選択し、上記のファイル名で保存する。

ライセンス上、リポジトリへの直接コミットは可だが、ダウンロード URL
(`https://cdn.lordicon.com/<asset-id>.json`) を実行時に取得することは
オフライン POS の前提に反するため禁止。必ずアセットとしてバンドルする。

## フォールバック

JSON ファイルが存在しない場合、`Lordicon` widget は Material Icon
(`Icons.*`) で自動フォールバックする。CI / 開発初期段階で JSON が未配置
でもアプリはクラッシュしない。
