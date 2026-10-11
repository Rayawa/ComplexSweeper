// 从原作 32×32 icon 生成启动图标，保留原作像素画。
// 三端统一：图案占可见图标边长 50%。Android 自适应图标的图层为 108dp，
// 可见窗口为 72dp，所以图案宽 36dp（图层的 1/3），而不是按完整图层计算。
// 自适应前景使用像素矩形组成的 VectorDrawable，避免位图密度缩放降低清晰度。
// 旧式 PNG 从 576px 母图按整数倍率降采样，576 可被全部五档尺寸整除。
// node --experimental-strip-types tools/make-icon.ts assets/atlas.json assets/atlas.png app/src/main/res

import * as fs from 'node:fs';
import * as path from 'node:path';
import { Bitmap, decodePng, encodePng } from './png.ts';

/** 可见图标中，原作图案占一半；与 Apple / HarmonyOS 一致。 */
const LEGACY_SHARE = 0.50;
const LEGACY_MASTER = 576;
/** 银灰底，和游戏里的 classic_face 一致 */
const BG = { r: 0xc0, g: 0xc0, b: 0xc0, a: 255 };

/** 每个密度目录对应的老式图标边长（mdpi 48 起） */
const LEGACY: Array<{ dir: string; size: number }> = [
  { dir: 'mipmap-mdpi', size: 48 },
  { dir: 'mipmap-hdpi', size: 72 },
  { dir: 'mipmap-xhdpi', size: 96 },
  { dir: 'mipmap-xxhdpi', size: 144 },
  { dir: 'mipmap-xxxhdpi', size: 192 },
];

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

/** 整数倍盒式降采样 */
function downSample(src: Bitmap, factor: number): Bitmap {
  if (!Number.isInteger(factor) || factor < 1 || src.width % factor !== 0 || src.height % factor !== 0) {
    throw new Error(`降采样必须使用可整除母图的整数倍率，收到 ${factor}`);
  }
  const w = src.width / factor;
  const h = src.height / factor;
  const out = Buffer.alloc(w * h * 4);
  const n = factor * factor;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let dy = 0; dy < factor; dy++) {
        for (let dx = 0; dx < factor; dx++) {
          const i = ((y * factor + dy) * src.width + (x * factor + dx)) * 4;
          r += src.data[i];
          g += src.data[i + 1];
          b += src.data[i + 2];
          a += src.data[i + 3];
        }
      }
      const o = (y * w + x) * 4;
      out[o] = Math.round(r / n);
      out[o + 1] = Math.round(g / n);
      out[o + 2] = Math.round(b / n);
      out[o + 3] = Math.round(a / n);
    }
  }
  return new Bitmap(w, h, out);
}

/** 把 art 居中贴到 size×size 画布上，长边占 share；opaque 为真时垫银灰底 */
function compose(art: Bitmap, size: number, share: number, opaque: boolean, circular = false): Bitmap {
  const out = Buffer.alloc(size * size * 4);
  if (opaque) {
    for (let i = 0; i < size * size; i++) {
      out[i * 4] = BG.r;
      out[i * 4 + 1] = BG.g;
      out[i * 4 + 2] = BG.b;
      out[i * 4 + 3] = BG.a;
    }
  }
  const target = size * share;
  const factor = Math.max(1, Math.round(target / Math.max(art.width, art.height)));
  const scaled = scaleUp(art, factor);
  const ox = Math.floor((size - scaled.width) / 2);
  const oy = Math.floor((size - scaled.height) / 2);
  const c = (size - 1) / 2;
  const radius = circular ? size / 2 : 0;

  for (let y = 0; y < scaled.height; y++) {
    for (let x = 0; x < scaled.width; x++) {
      const s = (y * scaled.width + x) * 4;
      const a = scaled.data[s + 3];
      if (a === 0) continue;
      const px = ox + x;
      const py = oy + y;
      if (circular) {
        const dx = px - c;
        const dy = py - c;
        if (dx * dx + dy * dy > radius * radius) continue;
      }
      const d = (py * size + px) * 4;
      if (a === 255) {
        out[d] = scaled.data[s];
        out[d + 1] = scaled.data[s + 1];
        out[d + 2] = scaled.data[s + 2];
      } else {
        const t = a / 255;
        out[d] = Math.round(scaled.data[s] * t + out[d] * (1 - t));
        out[d + 1] = Math.round(scaled.data[s + 1] * t + out[d + 1] * (1 - t));
        out[d + 2] = Math.round(scaled.data[s + 2] * t + out[d + 2] * (1 - t));
      }
      out[d + 3] = 255;
    }
  }
  if (circular) {
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        if ((x - c) ** 2 + (y - c) ** 2 > radius ** 2) out[(y * size + x) * 4 + 3] = 0;
      }
    }
  }
  return new Bitmap(size, size, out);
}

// ---------------- 主流程 ----------------

const jsonPath = process.argv[2];
const pngPath = process.argv[3];
const resDir = process.argv[4];

const atlas = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const src = decodePng(fs.readFileSync(pngPath));

const slot = (atlas.slots as Array<{ name: string; x: number; y: number; w: number; h: number }>)
  .find((s) => s.name === 'icon');
if (slot === undefined) {
  throw new Error('图集里没有 icon 槽位，做不了应用图标');
}
const raw = Buffer.alloc(slot.w * slot.h * 4);
for (let row = 0; row < slot.h; row++) {
  src.data.copy(raw, row * slot.w * 4,
    ((slot.y + row) * src.width + slot.x) * 4,
    ((slot.y + row) * src.width + slot.x + slot.w) * 4);
}
const art = new Bitmap(slot.w, slot.h, raw);

const write = (dir: string, name: string, bmp: Bitmap): void => {
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, name), encodePng(bmp));
};

// 将原作非透明像素按颜色合并为矢量路径。每一像素都是精确的矩形，
// 不做平滑重绘；108dp 图层内的 36dp 图案经系统裁切后占 72dp 窗口的一半。
const drawableDir = path.join(resDir, 'drawable');
fs.mkdirSync(drawableDir, { recursive: true });
const paths = new Map<string, string[]>();
const pixel = 36 / Math.max(art.width, art.height);
const ox = (108 - art.width * pixel) / 2;
const oy = (108 - art.height * pixel) / 2;
for (let y = 0; y < art.height; y++) {
  for (let x = 0; x < art.width;) {
    const i = (y * art.width + x) * 4;
    if (art.data[i + 3] === 0) { x++; continue; }
    // 同一行相邻同色像素合并成矩形，减少桌面渲染路径长度。
    let end = x + 1;
    while (end < art.width) {
      const j = (y * art.width + end) * 4;
      if (!art.data.subarray(i, i + 4).equals(art.data.subarray(j, j + 4))) break;
      end++;
    }
    const color = '#' + [art.data[i + 3], art.data[i], art.data[i + 1], art.data[i + 2]]
      .map(v => v.toString(16).padStart(2, '0')).join('');
    const commands = paths.get(color) ?? [];
    commands.push(`M${x},${y}h${end - x}v1h-${end - x}z`);
    paths.set(color, commands);
    x = end;
  }
}
const vectorHeader = '<?xml version="1.0" encoding="utf-8"?>\n'
  + '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">\n';
fs.writeFileSync(path.join(drawableDir, 'ic_launcher_foreground.xml'), vectorHeader
  + `    <group android:translateX="${ox}" android:translateY="${oy}" android:scaleX="${pixel}" android:scaleY="${pixel}">\n`
  + Array.from(paths, ([color, commands]) => `    <path android:fillColor="${color}" android:pathData="${commands.join(' ')}" />`).join('\n')
  + '\n    </group>\n</vector>\n');
fs.writeFileSync(path.join(drawableDir, 'ic_launcher_background.xml'), vectorHeader
  + '    <path android:fillColor="#FFC0C0C0" android:pathData="M0,0h108v108h-108z" />\n</vector>\n');
// 删除旧位图，避免同名资源与矢量冲突。
for (const name of ['ic_launcher_foreground.png', 'ic_launcher_background.png']) {
  fs.rmSync(path.join(drawableDir, name), { force: true });
}

// 老式图标：方形与圆形各一套
const master = compose(art, LEGACY_MASTER, LEGACY_SHARE, true);
const masterRound = compose(art, LEGACY_MASTER, LEGACY_SHARE, true, true);
for (const { dir, size } of LEGACY) {
  const factor = LEGACY_MASTER / size;
  write(path.join(resDir, dir), 'ic_launcher.png', downSample(master, factor));
  write(path.join(resDir, dir), 'ic_launcher_round.png', downSample(masterRound, factor));
}

// 标签页图标：三档难度 = 程序图标的三档大小。
// 画布尺寸固定，只有图案依次是 2×/3×/4× —— 图案占画布的比例小→大，
// 系统缩放到同一显示尺寸后才仍然是「初级小、高级大」。
// 放到 drawable-nodpi 而不是 mipmap：它和格子贴图一样是像素画，一个像素对一个 dp。
const TAB_CANVAS = 128;
const TAB_FACTORS: number[] = [2, 3, 4];
const tabDir = path.join(resDir, 'drawable-nodpi');
for (let i = 0; i < TAB_FACTORS.length; i++) {
  const share = (art.width * TAB_FACTORS[i]) / TAB_CANVAS;
  write(tabDir, `cw_tab_${i + 1}.png`, compose(art, TAB_CANVAS, share, false));
}

console.log(`应用图标写好：自适应矢量两层 + ${LEGACY.length} 档密度的方形/圆形 + ${TAB_FACTORS.length} 张标签页图标，输出到 ${resDir}`);
