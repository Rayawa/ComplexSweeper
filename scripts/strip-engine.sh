#!/usr/bin/env bash
#
# 把引擎源码里的 ArkTS 装饰器剥掉，输出 Node 能直接跑的 TypeScript。
#
# 这些文件里唯一一个"运行时"装饰器是 @Observed，其余全是类型标注，
# Node 24 自己就能剥掉。所以校验脚本用的是当前源码本体，不存在副本走样。
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../entry/src/main/ets"

for f in model/Complex.ets model/Difficulty.ets engine/Board.ets; do
  sed -e '/^import /d' -e 's/^export //' -e '/^@Observed$/d' "$SRC/$f"
done
