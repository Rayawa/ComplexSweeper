#!/usr/bin/env bash
#
# 引擎逻辑校验。
#
#   ./scripts/engine-check/run.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

"$HERE/../strip-engine.sh" > "$OUT/engine.ts"
cat "$OUT/engine.ts" "$HERE/engine.test.ts" > "$OUT/run.ts"
node "$OUT/run.ts"
