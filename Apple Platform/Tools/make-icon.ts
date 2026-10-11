// 用图集里的 icon 槽位（32×32）生成 Xcode 的 AppIcon.appiconset。
//
// 三种平台共用一套：iOS / iPadOS 只要一张 1024×1024；macOS 要 16…512 的 1x/2x。
// 所以先做一张 1024 的母图（像素画最近邻放大 + 居中留白），再按整数倍做盒式降采样
// 得到小尺寸 —— 整数倍均值降采样出来的小图标比直接最近邻抽点干净。
//
// 图标必须不透明：iOS 应用图标带 alpha 通道会被 App Store 拒。图集里的 icon 槽位
// 是透明底的像素画，这里垫上经典扫雷的银灰 #C0C0C0（上游给这套图标配的底色也正好
// 是这个值），出来的就是全不透明。
//
//   node --experimental-strip-types make-icon.ts <图集.json> <图集.png> <Assets.xcassets 目录>

import * as fs from 'node:fs';
import * as path from 'node:path';
import { Bitmap, decodePng, encodePng } from './png.ts';

/** 母图边长 */
const MASTER = 1024;
/** 与 HarmonyOS 一致：32×32 原作图案占可见图标边长的一半。 */
const ART_SHARE_IOS = 0.50;
const ART_SHARE_MAC = 0.50;
/** 银灰底，和游戏里的 classic_face 一致 */
const BG = { r: 0xc0, g: 0xc0, b: 0xc0, a: 255 };

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

/** 整数倍盒式降采样：factor 必须是 MASTER 的因数 */
function downSample(src: Bitmap, factor: number): Bitmap {
  const w = src.width / factor;
  const h = src.height / factor;
  if (!Number.isInteger(w) || !Number.isInteger(h)) {
    throw new Error(`降采样倍数 ${factor} 不能整除 ${src.width}x${src.height}`);
  }
  const out = Buffer.alloc(w * h * 4);
  const n = factor * factor;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let r = 0;
      let g = 0;
      let b = 0;
      let a = 0;
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

/** 把 src 居中贴到 MASTER×MASTER 的银灰底上，长边占 share */
function composeMaster(src: Bitmap, share: number): Bitmap {
  const target = Math.round(MASTER * share);
  // 只用整数倍放大，不够的零头靠两侧留白补 —— 放大倍数非整数会破坏像素网格
  const factor = Math.max(1, Math.floor(target / Math.max(src.width, src.height)));
  const art = scaleUp(src, factor);
  const out = Buffer.alloc(MASTER * MASTER * 4);
  for (let i = 0; i < MASTER * MASTER; i++) {
    out[i * 4] = BG.r;
    out[i * 4 + 1] = BG.g;
    out[i * 4 + 2] = BG.b;
    out[i * 4 + 3] = BG.a;
  }
  const ox = Math.floor((MASTER - art.width) / 2);
  const oy = Math.floor((MASTER - art.height) / 2);
  for (let y = 0; y < art.height; y++) {
    for (let x = 0; x < art.width; x++) {
      const s = (y * art.width + x) * 4;
      const a = art.data[s + 3];
      if (a === 0) {
        continue;
      }
      const d = ((oy + y) * MASTER + (ox + x)) * 4;
      if (a === 255) {
        out[d] = art.data[s];
        out[d + 1] = art.data[s + 1];
        out[d + 2] = art.data[s + 2];
      } else {
        const t = a / 255;
        out[d] = Math.round(art.data[s] * t + out[d] * (1 - t));
        out[d + 1] = Math.round(art.data[s + 1] * t + out[d + 1] * (1 - t));
        out[d + 2] = Math.round(art.data[s + 2] * t + out[d + 2] * (1 - t));
      }
      out[d + 3] = 255;
    }
  }
  return new Bitmap(MASTER, MASTER, out);
}

// ---------------- 主流程 ----------------

const jsonPath = process.argv[2];
const pngPath = process.argv[3];
const catalogDir = process.argv[4];

const atlas = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const src = decodePng(fs.readFileSync(pngPath));

const slot = (atlas.slots as Array<{ name: string; x: number; y: number; w: number; h: number }>)
  .find((s) => s.name === 'icon');
if (slot === undefined) {
  throw new Error('图集里没有 icon 槽位，做不了应用图标');
}
const art = new Bitmap(slot.w, slot.h, Buffer.from(
  (() => {
    const out = Buffer.alloc(slot.w * slot.h * 4);
    for (let row = 0; row < slot.h; row++) {
      src.data.copy(out, row * slot.w * 4,
        ((slot.y + row) * src.width + slot.x) * 4,
        ((slot.y + row) * src.width + slot.x + slot.w) * 4);
    }
    return out;
  })()
));

const iosMaster = composeMaster(art, ART_SHARE_IOS);
const macMaster = composeMaster(art, ART_SHARE_MAC);

const setDir = path.join(catalogDir, 'AppIcon.appiconset');
fs.mkdirSync(setDir, { recursive: true });

interface Entry {
  filename: string;
  idiom: string;
  scale?: string;
  size: string;
  platform?: string;
}

const entries: Entry[] = [];
const write = (bmp: Bitmap, filename: string): void => {
  fs.writeFileSync(path.join(setDir, filename), encodePng(bmp));
};

// iOS / iPadOS：单尺寸 1024
const iosName = 'AppIcon-ios-1024.png';
write(iosMaster, iosName);
entries.push({ filename: iosName, idiom: 'universal', platform: 'ios', size: '1024x1024' });

// macOS：16…512 各 1x 与 2x
const MAC_SIZES: number[] = [16, 32, 128, 256, 512];
for (const size of MAC_SIZES) {
  for (const scale of [1, 2]) {
    const px = size * scale;
    const factor = MASTER / px;
    if (!Number.isInteger(factor)) {
      throw new Error(`macOS 图标 ${px}px 不是母图 ${MASTER} 的整数分之一`);
    }
    const name = `AppIcon-mac-${size}x${size}@${scale}x.png`;
    write(downSample(macMaster, factor), name);
    entries.push({ filename: name, idiom: 'mac', scale: `${scale}x`, size: `${size}x${size}` });
  }
}

fs.writeFileSync(path.join(setDir, 'Contents.json'),
  `${JSON.stringify({ images: entries, info: { author: 'xcode', version: 1 } }, null, 2)}\n`);

// ---------------- 标签页图标 ----------------
//
// 三档难度 = 程序图标的三档大小。画布尺寸固定，只有图案依次是 2×/3×/4× ——
// 图案占画布的比例小→大，系统缩放到同一显示尺寸后才仍然是「初级小、高级大」。
const TAB_CANVAS = 128;
const TAB_FACTORS: number[] = [2, 3, 4];
for (let i = 0; i < TAB_FACTORS.length; i++) {
  const canvas = Buffer.alloc(TAB_CANVAS * TAB_CANVAS * 4);
  const scaled = scaleUp(art, TAB_FACTORS[i]);
  const ox = Math.floor((TAB_CANVAS - scaled.width) / 2);
  const oy = Math.floor((TAB_CANVAS - scaled.height) / 2);
  for (let y = 0; y < scaled.height; y++) {
    scaled.data.copy(
      canvas,
      ((oy + y) * TAB_CANVAS + ox) * 4,
      y * scaled.width * 4,
      (y * scaled.width + scaled.width) * 4,
    );
  }

  const name = `cw_tab_${i + 1}`;
  const imagesetDir = path.join(catalogDir, `${name}.imageset`);
  fs.mkdirSync(imagesetDir, { recursive: true });
  const fileName = `${name}.png`;
  fs.writeFileSync(path.join(imagesetDir, fileName), encodePng(new Bitmap(TAB_CANVAS, TAB_CANVAS, canvas)));
  fs.writeFileSync(path.join(imagesetDir, 'Contents.json'), `${JSON.stringify({
    images: [{ filename: fileName, idiom: 'universal' }],
    info: { author: 'xcode', version: 1 },
  }, null, 2)}\n`);
}

console.log(`AppIcon.appiconset 写好：1 张 iOS 1024 + ${entries.length - 1} 张 macOS；`
  + `${TAB_FACTORS.length} 张标签页图标写入 ${catalogDir}`);
