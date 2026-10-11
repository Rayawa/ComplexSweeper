// 用图集里的 icon 槽位（32×32）生成 HarmonyOS 的分层应用图标。
//
// 分层图标要 1024×1024 的前景和背景，前景里的图案还得待在中间的安全区里
// （外面一圈会被系统按圆角/圆形裁掉）。所以这里把 32×32 放大 16 倍成 512×512
// 居中放进去 —— 正好占一半，怎么裁都不会切到图案。
//
// 同一套图标要写两处：AppScope 的是应用图标，模块 media 里的是 ability 图标
// （桌面 Launcher 显示的是后者）。启动窗口图标（startWindowIcon）也从 icon 槽位出，
// 透明底不放背景 —— 系统会把它垫在 startWindowBackground（本工程是银灰）上。
//
// 标签页图标也出自 icon 槽位：三档难度 = 同一个图案的三档大小，画在**同尺寸**的
// 透明画布上。画布必须一样大 —— 画布跟着图案一起变的话，系统把每张图各自缩放到
// 同一个显示尺寸，三个图案就又一样大了，递进就没了。
//
//   node --experimental-strip-types make-icon.ts <icon.png> <AppScope目录> [模块media目录]

import * as fs from 'node:fs';
import * as path from 'node:path';
import { Bitmap, decodePng, encodePng } from './png.ts';

const CANVAS = 1024;
const SCALE = 16;
/** 标签页图标：画布 128×128，三档难度用 icon 的 2×/3×/4× 大小做出递进 */
const TAB_SIZE = 128;
const TAB_FACTORS: number[] = [2, 3, 4];
/** 启动窗口图标：原模板是 152×152，高倍屏上偏糊，给足到 512 */
const START_SIZE = 512;

const srcPath = process.argv[2];
const appScopeDir = process.argv[3];
/** 模块 media 目录：ability 分层图标、启动图标与标签页图标都写这里 */
const MEDIA_DIR: string = process.argv[4] ?? path.dirname(srcPath);

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

/** 全透明画布：底色透明，等系统或调用方往上垫东西 */
function transparent(width: number, height: number): Bitmap {
  const bmp = solid(width, height, 0, 0, 0);
  for (let i = 0; i < width * height; i++) {
    bmp.data[i * 4 + 3] = 0;
  }
  return bmp;
}

/** 往一个 media 目录里写一套分层图标（background + foreground 两图层） */
function writeLayered(outDir: string): void {
  // 背景：经典扫雷的面板银灰
  const background = solid(CANVAS, CANVAS, 0xC0, 0xC0, 0xC0);
  // 前景：图标居中；底色透明，系统会在下面垫背景层
  const foreground = transparent(CANVAS, CANVAS);
  center(foreground, scaleUp(icon, SCALE));

  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, 'background.png'), encodePng(background));
  fs.writeFileSync(path.join(outDir, 'foreground.png'), encodePng(foreground));
  console.log(`分层图标已写入 ${outDir}（前景 ${CANVAS}×${CANVAS}，图案 ${icon.width * SCALE}×${icon.height * SCALE} 居中）`);
}

/** 启动窗口图标：透明底，直接放大到 512（32 的整数倍），图案与桌面图标同一套 */
const startScale = Math.max(1, Math.round(START_SIZE / icon.width));
fs.mkdirSync(MEDIA_DIR, { recursive: true });
fs.writeFileSync(path.join(MEDIA_DIR, 'startIcon.png'), encodePng(scaleUp(icon, startScale)));
console.log(`启动窗口图标 startIcon.png（${icon.width * startScale}×${icon.height * startScale}，透明底）`);

writeLayered(appScopeDir);
if (MEDIA_DIR !== appScopeDir) {
  writeLayered(MEDIA_DIR);
}

// 标签页图标：三档难度 = 程序图标的三档大小。
// 画布尺寸固定，只有图案依次是 2×/3×/4× —— 图案占画布的比例小→大，
// 系统缩放到同一显示尺寸后才仍然是"初级小、高级大"。
for (let i = 0; i < TAB_FACTORS.length; i++) {
  const factor = TAB_FACTORS[i];
  const canvas = transparent(TAB_SIZE, TAB_SIZE);
  center(canvas, scaleUp(icon, factor));
  const out = `cw_tab_${i + 1}.png`;
  fs.writeFileSync(path.join(MEDIA_DIR, out), encodePng(canvas));
  console.log(`  标签页图标 ${out}（画布 ${TAB_SIZE}×${TAB_SIZE}，图案 ${icon.width * factor}×${icon.height * factor}）`);
}
