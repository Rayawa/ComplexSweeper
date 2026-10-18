// 把复扫雷的图集（一张 PNG + 一份槽位 JSON）切成一张张独立 PNG，
// 写进 Android 的 res/drawable-nodpi/。
//
// 手边没有 ImageMagick / PIL，所以用 Node 自带的 zlib 自己解 PNG、自己编 PNG
// （见同目录 png.ts）。
//
//   node --experimental-strip-types slice-atlas.ts <图集.json> <图集.png> <drawable-nodpi 目录>
//
// 之所以放 -nodpi：这批贴图是像素画，每个像素就该对应一个 dp。
// 放进带密度的目录，系统会按密度再缩一次，格子就不是整数像素了。
// 缩放交给 Compose 的 FilterQuality.None 做最近邻。

import * as fs from 'node:fs';
import * as path from 'node:path';
import { Bitmap, decodePng, encodePng } from './png.ts';

function crop(src: Bitmap, x: number, y: number, w: number, h: number, icon: boolean = false): Bitmap {
  if (x < 0 || y < 0 || x + w > src.width || y + h > src.height) {
    throw new Error(`槽位越界：(${x},${y}) ${w}x${h} 超出 ${src.width}x${src.height}`);
  }
  const out = Buffer.alloc(w * h * 4);
  for (let row = 0; row < h; row++) {
    src.data.copy(out, row * w * 4, ((y + row) * src.width + x) * 4, ((y + row) * src.width + x + w) * 4);
  }
  // 与上游 gen_atlas.js 一致：使用作者的黑白图集，非图标透明处合成到银灰底。
  if (prefix === 'cw_bw_') {
    for (let i = 0; i < out.length; i += 4) {
      const alpha = icon ? 1 : out[i + 3] / 255;
      const r = Math.round(out[i] * alpha + 192 * (1 - alpha));
      const g = Math.round(out[i + 1] * alpha + 192 * (1 - alpha));
      const b = Math.round(out[i + 2] * alpha + 192 * (1 - alpha));
      out[i] = out[i + 1] = out[i + 2] = Math.round(0.299 * r + 0.587 * g + 0.114 * b);
      if (!icon) out[i + 3] = 255;
    }
  }
  return new Bitmap(w, h, out);
}

// ---------------- 主流程 ----------------

const jsonPath = process.argv[2];
const pngPath = process.argv[3];
const outDir = process.argv[4];
const prefix = process.argv[5] ?? 'cw_';

interface Slot {
  name: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

const atlas = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const src = decodePng(fs.readFileSync(pngPath));
if (src.width !== atlas.width || src.height !== atlas.height) {
  throw new Error(`图集尺寸对不上：JSON 说 ${atlas.width}x${atlas.height}，PNG 是 ${src.width}x${src.height}`);
}

// 两种模式使用同一份完整图集。

fs.mkdirSync(outDir, { recursive: true });
let written = 0;

for (const slot of atlas.slots as Slot[]) {
  const name = `${prefix}${slot.name}`;
  // Android 资源名只接受小写字母、数字、下划线，且不能以数字开头
  if (!/^[a-z][a-z0-9_]*$/.test(name)) {
    throw new Error(`资源名不合规（Android 只接受小写字母、数字、下划线）：${name}`);
  }
  fs.writeFileSync(path.join(outDir, `${name}.png`), encodePng(crop(src, slot.x, slot.y, slot.w, slot.h, slot.name === 'icon')));
  written++;
}

console.log(`切出 ${written} 张，输出到 ${outDir}`);
