#!/usr/bin/env bash
#
# 界面预览：把 ArkUI 的排版、字号、配色渲染成 HTML 并截图。
#
# 这是给"没有真机时能不能看出毛病"兜底的：颜色直接读 color.json，
# 字号和分档直接调引擎里同一个函数，所以预览和真实界面共用同一套规则。
# 它验不了 ArkUI 的运行时行为，只能验排版和观感。
#
#   ./scripts/ui-preview/run.sh [输出目录]
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$PROJECT/build/ui-preview}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

"$HERE/../strip-engine.sh" > "$TMP/engine.ts"
cat "$TMP/engine.ts" "$HERE/gen.ts" > "$TMP/gen.ts"
mkdir -p "$OUT"
node "$TMP/gen.ts" "$PROJECT" "$OUT"

if [ ! -x "$CHROME" ]; then
  echo "未找到 Chrome，只生成了 HTML：$OUT"
  exit 0
fi

shopt -s nullglob
for f in "$OUT"/*.html; do
  name="$(basename "$f" .html)"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --screenshot="$OUT/$name.png" --window-size=360,780 "file://$f" >/dev/null 2>&1
done
echo "截图输出：$OUT"
