// 把复扫雷的图集（一张 PNG + 一份槽位 JSON）切成一张张独立 PNG，
// 写进 HarmonyOS 的 media 资源目录。手边没有 ImageMagick / PIL，
// 所以用 Node 自带的 zlib 自己解 PNG、自己编 PNG。
//
//   node --experimental-strip-types slice.ts <图集.json> <图集.png> <输出目录> [文件名前缀]

import * as fs from 'node:fs';
import * as path from 'node:path';
import { Bitmap, decodePng, encodePng } from './png.ts';

function crop(src: Bitmap, x: number, y: number, w: number, h: number): Bitmap {
  if (x < 0 || y < 0 || x + w > src.width || y + h > src.height) {
    throw new Error(`槽位越界：(${x},${y}) ${w}x${h} 超出 ${src.width}x${src.height}`);
  }
  const out = Buffer.alloc(w * h * 4);
  for (let row = 0; row < h; row++) {
    src.data.copy(out, row * w * 4, ((y + row) * src.width + x) * 4, ((y + row) * src.width + x + w) * 4);
  }
  return new Bitmap(w, h, out);
}

// ---------------- 主流程 ----------------

const jsonPath = process.argv[2];
const pngPath = process.argv[3];
const outDir = process.argv[4];
const prefix = process.argv[5] ?? '';

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

// 双曲复数模式（j²=1）那批素材这次用不到，跳过。
// led_j 是那个模式的 j 单位，前缀不带 h，得单独排掉。
const HYPER = /^(h(num|flag|mine|boom|wrong|right|led)|led_j$)/;

fs.mkdirSync(outDir, { recursive: true });
let written = 0;
const skipped: string[] = [];

for (const slot of atlas.slots as Slot[]) {
  if (HYPER.test(slot.name)) {
    skipped.push(slot.name);
    continue;
  }
  const name = `${prefix}${slot.name}`;
  if (!/^[a-z][a-z0-9_]*$/.test(name)) {
    throw new Error(`资源名不合规（HarmonyOS 只接受小写字母、数字、下划线）：${name}`);
  }
  fs.writeFileSync(path.join(outDir, `${name}.png`), encodePng(crop(src, slot.x, slot.y, slot.w, slot.h)));
  written++;
}

console.log(`切出 ${written} 张，跳过 ${skipped.length} 张双曲模式素材，输出到 ${outDir}`);
