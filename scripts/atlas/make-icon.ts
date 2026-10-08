// 用图集里的 icon 槽位（32×32）生成 HarmonyOS 的分层应用图标。
//
// 分层图标要 1024×1024 的前景和背景，前景里的图案还得待在中间的安全区里
// （外面一圈会被系统按圆角/圆形裁掉）。所以这里把 32×32 放大 16 倍成 512×512
// 居中放进去 —— 正好占一半，怎么裁都不会切到图案。
//
//   node --experimental-strip-types make-icon.ts <icon.png> <输出目录>

import * as fs from 'node:fs';
import * as path from 'node:path';
import { Bitmap, decodePng, encodePng } from './png.ts';

const CANVAS = 1024;
const SCALE = 16;
/** 标签页图标：贴图是 16×16，放大会糊，所以先切成 96×96 让系统缩着用 */
const TAB_SIZE = 96;

const srcPath = process.argv[2];
const outDir = process.argv[3];
/** 可选：标签页图标输出目录 + 用哪几个槽位 */
const TAB_SLOTS: string[] = (process.argv[4] ?? 'cw_flag_1,cw_flag_2,cw_flag_3').split(',');
const MEDIA_DIR: string = process.argv[5] ?? path.dirname(srcPath);

const icon = decodePng(fs.readFileSync(srcPath));

/** 最近邻放大：像素画放大只能用这个，插值一开就糊 */
function scaleUp(src: Bitmap, factor: number): Bitmap {
  const w = src.width * factor;
  const h = src.height * factor;
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const sy = Math.floor(y / factor);
    for (let x = 0; x < w; x++) {
      const sx = Math.floor(x / factor);
      src.data.copy(out, (y * w + x) * 4, (sy * src.width + sx) * 4, (sy * src.width + sx) * 4 + 4);
    }
  }
  return new Bitmap(w, h, out);
}

/** 把一张图贴到纯色画布正中间 */
function center(base: Bitmap, layer: Bitmap): void {
  const ox = Math.floor((base.width - layer.width) / 2);
  const oy = Math.floor((base.height - layer.height) / 2);
  for (let y = 0; y < layer.height; y++) {
    // 用「over」方式混：前景带 alpha，不能直接覆盖
    for (let x = 0; x < layer.width; x++) {
      const si = (y * layer.width + x) * 4;
      const a = layer.data[si + 3] / 255;
      if (a === 0) {
        continue;
      }
      const di = ((oy + y) * base.width + ox + x) * 4;
      for (let c = 0; c < 3; c++) {
        base.data[di + c] = Math.round(layer.data[si + c] * a + base.data[di + c] * (1 - a));
      }
      base.data[di + 3] = 255;
    }
  }
}

function solid(width: number, height: number, r: number, g: number, b: number): Bitmap {
  const data = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    data[i * 4] = r;
    data[i * 4 + 1] = g;
    data[i * 4 + 2] = b;
    data[i * 4 + 3] = 255;
  }
  return new Bitmap(width, height, data);
}

// 背景：经典扫雷的面板银灰
const background = solid(CANVAS, CANVAS, 0xC0, 0xC0, 0xC0);
// 前景：图标居中；底色透明，系统会在下面垫背景层
const foreground = solid(CANVAS, CANVAS, 0, 0, 0);
for (let i = 0; i < CANVAS * CANVAS; i++) {
  foreground.data[i * 4 + 3] = 0;
}
center(foreground, scaleUp(icon, SCALE));

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'background.png'), encodePng(background));
fs.writeFileSync(path.join(outDir, 'foreground.png'), encodePng(foreground));
console.log(`应用图标已写入 ${outDir}（前景 ${CANVAS}×${CANVAS}，图案 ${icon.width * SCALE}×${icon.height * SCALE} 居中）`);

// 标签页图标：整数倍放大到接近 96，交给系统缩小显示。
// 比例要按各自贴图的尺寸算，不能拿上面那张 icon 的尺寸套。
for (let i = 0; i < TAB_SLOTS.length; i++) {
  const name = TAB_SLOTS[i];
  const src = decodePng(fs.readFileSync(path.join(MEDIA_DIR, `${name}.png`)));
  const factor = Math.max(1, Math.round(TAB_SIZE / src.width));
  const out = `${name.replace('cw_flag_', 'cw_tab_')}.png`;
  fs.writeFileSync(path.join(MEDIA_DIR, out), encodePng(scaleUp(src, factor)));
  console.log(`  标签页图标 ${out}（${src.width * factor}×${src.height * factor}）`);
}
