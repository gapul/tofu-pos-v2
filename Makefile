# Tofu POS — 開発タスクのショートカット
#
# 使用例:
#   make test       テスト実行
#   make analyze    静的解析
#   make codegen    コード生成（drift / freezed / json_serializable）
#   make ci         analyze + test を順に（CI と同じチェック）
#   make run        実機/シミュレータで起動
#   make clean      ビルド成果物の削除

.PHONY: help deps codegen analyze test ci run clean fmt watch hooks

help:
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

deps: ## 依存パッケージを解決
	flutter pub get

codegen: ## drift / freezed / json_serializable のコード生成
	dart run build_runner build --delete-conflicting-outputs

watch: ## コード生成の watch モード
	dart run build_runner watch --delete-conflicting-outputs

fmt: ## dart format を実行
	dart format lib test

analyze: ## 静的解析（CI と同じチェック）
	flutter analyze

test: ## 全テスト実行
	flutter test

ci: analyze test ## CI と同じ流れ（analyze → test）

run: ## 接続中の実機/シミュレータで起動
	flutter run

clean: ## ビルド成果物の削除
	flutter clean
	flutter pub get

hooks: ## lefthook をインストール
	lefthook install
