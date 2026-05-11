#!/usr/bin/env bash
# ローカル開発用の flutter run ラッパー。
# .env を読み込んで --dart-define として渡す。
# .env は assets に含めないので、このスクリプト経由で起動する。
#
# 使い方:
#   tools/run-dev.sh                   # 既定の方法で flutter run
#   tools/run-dev.sh -d <device-id>    # 端末指定
#   tools/run-dev.sh build ipa         # release ビルドに渡しても OK

set -euo pipefail

# プロジェクトルートで実行することを前提に .env を探す。
ENV_FILE="${ENV_FILE:-.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[run-dev] $ENV_FILE が見つかりません。" >&2
  echo "  SUPABASE_URL と SUPABASE_ANON_KEY を含む .env を用意するか、" >&2
  echo "  ENV_FILE 環境変数でパスを指定してください。" >&2
  exit 1
fi

# .env を read。export しないが、シェル変数として参照できるようにする。
# shellcheck disable=SC1090
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

DEFINES=(
  --dart-define=SUPABASE_URL="$SUPABASE_URL"
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
)

# 第1引数が `build` / `run` 等のコマンドなら尊重、無ければ `run` を補う。
if [[ $# -eq 0 || "$1" != "run" && "$1" != "build" && "$1" != "test" && "$1" != "drive" ]]; then
  set -- run "$@"
fi

exec flutter "$@" "${DEFINES[@]}"
