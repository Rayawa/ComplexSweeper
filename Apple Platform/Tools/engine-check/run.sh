#!/usr/bin/env bash
#
# 引擎逻辑校验。
#
#   ./Tools/engine-check/run.sh
#
# 把引擎源码和断言一起交给 swiftc 编成命令行程序跑一遍。断言与 HarmonyOS 版
# scripts/engine-check/engine.test.ts 一一对应，固定种子也是同一批 —— 三个平台
# 的引擎跑出来的是同一个棋盘。
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/../../ComplexSweeper-Apple"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# -disable-sandbox：Swift 的宏插件默认在嵌套沙箱里跑，CI 或受限环境下会被拒。
# 自检只是本地跑一段纯逻辑，不需要那层沙箱。
swiftc -O -disable-sandbox \
  -module-cache-path "${MODULE_CACHE_PATH:-$OUT/modcache}" \
  -o "$OUT/engine-check" \
  "$APP/Model/Complex.swift" \
  "$APP/Model/Difficulty.swift" \
  "$APP/Model/Stats.swift" \
  "$APP/Engine/BoardModel.swift" \
  "$APP/Engine/Board.swift" \
  "$HERE/main.swift"

"$OUT/engine-check"
