// 把复扫雷的图集（一张 PNG + 一份槽位 JSON）切成一张张独立 PNG，
// 直接写成 Xcode 资源目录（Assets.xcassets）里的 imageset。
//
// 手边没有 ImageMagick / PIL，所以用 Node 自带的 zlib 自己解 PNG、自己编 PNG
// （见同目录 png.ts）。
//
//   node --experimental-strip-types slice-atlas.ts <图集.json> <图集.png> <Assets.xcassets 目录>
//
// 每个槽位写成一个 <前缀><槽位名>.imageset/，里面是 Contents.json + 那张 PNG。
// Contents.json 用「Single Scale」写法（images 项不带 scale 字段）：像素画只该有
// 一份原始位图，让系统按 1 点 = 1 像素解释，放大交给 SwiftUI 的
// .interpolation(.none) 做最近邻 —— 一旦补上 2x/3x 槽位，系统就会替你缩放，
// 反而糊掉。

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

/** Single Scale 的 imageset 描述 */
function contentsJson(fileName: string): string {
  return `${JSON.stringify({
    images: [{ filename: fileName, idiom: 'universal' }],
    info: { author: 'xcode', version: 1 },
  }, null, 2)}\n`;
}

// ---------------- 主流程 ----------------

const jsonPath = process.argv[2];
const pngPath = process.argv[3];
const catalogDir = process.argv[4];
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

fs.mkdirSync(catalogDir, { recursive: true });
let written = 0;

for (const slot of atlas.slots as Slot[]) {
  const name = `${prefix}${slot.name}`;
  if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(name)) {
    throw new Error(`资源名不合规：${name}`);
  }
  const imagesetDir = path.join(catalogDir, `${name}.imageset`);
  fs.mkdirSync(imagesetDir, { recursive: true });
  const fileName = `${name}.png`;
  fs.writeFileSync(path.join(imagesetDir, fileName), encodePng(crop(src, slot.x, slot.y, slot.w, slot.h)));
  fs.writeFileSync(path.join(imagesetDir, 'Contents.json'), contentsJson(fileName));
  written++;
}

console.log(`切出 ${written} 张 imageset，输出到 ${catalogDir}`);
