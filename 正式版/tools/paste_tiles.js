/* 把画好的单张贴图贴回大图集（素材/图集.png + 图集.json）。
   单张图的命名（三种写法都认，放在 素材/双曲复数新增/ 里，目录可用参数改）：
     数字<显示值>.png   例：数字2√3.png → D=12 → 槽位 hnum_12
                             数字2i.png  → D=−4 → 槽位 hnum_4_i
                             数字√3i.png → D=−3 → 槽位 hnum_3_i
     计时i.png / 计时j.png        → 槽位 led_i / led_j
     直接写槽位名.png            例：hnum_12.png
   只覆盖点名的槽位，图集其它像素一格不动；贴完报"还有哪些槽位仍是占位图"
   （占位图的字色是紫红 160,0,160，一眼能认出来）。

   用法: node tools/paste_tiles.js [单张图目录=../素材/双曲复数新增] [--dry] */
const fs = require('fs');
const path = require('path');
const { readPNG, writePNG } = require('./png.js');
const { VALUES } = require('./hyper_values.js');

const root = path.resolve(__dirname, '..', '..');           // 项目根
const proj = path.resolve(__dirname, '..');
const SHEET = path.join(root, '素材', '图集.png');
const META = path.join(root, '素材', '图集.json');
const argv = process.argv.slice(2);
const dry = argv.includes('--dry');
const looseArg = argv.find((a) => !a.startsWith('--'));
const LOOSE = looseArg ? path.resolve(looseArg) : path.join(root, '素材', '双曲复数新增');
const PLACEHOLDER_RGB = [160, 0, 160];                      // add_hyperbolic_tiles 画占位图用的字色

/* ---------- 显示值文本 → 槽位名 ---------- */
const byText = new Map(VALUES.map((v) => [v.text, v.name]));
byText.set('计时i', 'led_i');
byText.set('计时j', 'led_j');
byText.set('计时i.png', 'led_i');
byText.set('计时j.png', 'led_j');

const meta = JSON.parse(fs.readFileSync(META, 'utf8'));
const sheet = readPNG(SHEET);
if (sheet.w !== meta.width || sheet.h !== meta.height) throw new Error('图集尺寸与 json 不符');
const slotOf = new Map(meta.slots.map((s, i) => [s.name, { s, i }]));

function resolveTarget(file) {
  const base = path.basename(file).replace(/\.png$/i, '');
  if (slotOf.has(base)) return { name: base, how: '槽位名' };
  const key = base.replace(/^数字/, '');
  const name = byText.get(key);
  if (name) return { name, how: '显示值 ' + key };
  return null;
}

if (!fs.existsSync(LOOSE)) throw new Error('没有这个目录：' + LOOSE);
const files = fs.readdirSync(LOOSE).filter((f) => /\.png$/i.test(f)).sort();
if (files.length === 0) {
  console.log('目录里没有 PNG：' + LOOSE);
  process.exit(0);
}

const big = Buffer.from(sheet.rgba);
let pasted = 0;
const unknown = [];
const sizeBad = [];
const done = new Set();
for (const f of files) {
  const t = resolveTarget(f);
  if (!t) { unknown.push(f); continue; }
  const { s } = slotOf.get(t.name);
  const im = readPNG(path.join(LOOSE, f));
  if (im.w !== s.w || im.h !== s.h) { sizeBad.push(`${f}（${im.w}×${im.h}，槽位要 ${s.w}×${s.h}）`); continue; }
  for (let r = 0; r < s.h; r++) {
    im.rgba.copy(big, ((s.y + r) * sheet.w + s.x) * 4, r * s.w * 4, (r + 1) * s.w * 4);
  }
  pasted += 1;
  done.add(t.name);
  console.log(`  贴入 ${f.padEnd(18)} → ${t.name.padEnd(12)} @(${s.x},${s.y})  ${t.how}`);
}
for (const u of unknown) console.log('  跳过（认不出对应哪个槽位）：' + u);
for (const b of sizeBad) console.log('  跳过（尺寸不对）：' + b);

if (pasted > 0 && !dry) writePNG(SHEET, sheet.w, sheet.h, big);

/* ---------- 还能直接复用复数模式那 12 张的，自动复制过来 ---------- */
/* 显示文本一模一样的值（0 1 2 √5 2√2 3 4 5 4√2 6 7 8）在复数模式里已经有真素材了，
   双曲模式没必要重画：占位图原样留着的话这里就把它换成 num_<D> 那张。
   判定"还是占位图"看的是像素——占位图的字色是紫红 160,0,160，真素材里不会出现。 */
const CPLX_Ds = [0, 1, 2, 4, 5, 8, 9, 10, 13, 16, 17, 18, 20, 25, 26, 29, 32, 34, 36, 37, 40, 49, 50, 64];
function slotPixels(s) {
  const buf = Buffer.alloc(s.w * s.h * 4);
  for (let r = 0; r < s.h; r++) big.copy(buf, r * s.w * 4, ((s.y + r) * sheet.w + s.x) * 4, ((s.y + r) * sheet.w + s.x + s.w) * 4);
  return buf;
}
function hasPlaceholder(buf) {
  for (let i = 0; i < buf.length; i += 4) {
    if (buf[i] === PLACEHOLDER_RGB[0] && buf[i + 1] === PLACEHOLDER_RGB[1] && buf[i + 2] === PLACEHOLDER_RGB[2]) return true;
  }
  return false;
}
const reused = [];
for (const v of VALUES) {
  if (v.D < 0) continue;                                    // 负值是"根式 + i"，文本和复数模式不同，复用不了
  if (!CPLX_Ds.includes(v.D)) continue;
  const src = slotOf.get('num_' + v.D);
  const dst = slotOf.get('hnum_' + v.D);
  if (!src || !dst) continue;
  if (!hasPlaceholder(slotPixels(dst.s))) continue;          // 已经贴了真素材（或刚贴过）就不动
  const px = slotPixels(src.s);
  for (let r = 0; r < dst.s.h; r++) {
    px.copy(big, ((dst.s.y + r) * sheet.w + dst.s.x) * 4, r * dst.s.w * 4, (r + 1) * dst.s.w * 4);
  }
  reused.push(v.text);
}
if (reused.length) console.log(`\n  直接复用复数模式那 12 张里的 ${reused.length} 张：${reused.join(' ')}`);
if ((pasted > 0 || reused.length > 0) && !dry) writePNG(SHEET, sheet.w, sheet.h, big);

/* ---------- 还有哪些槽位是占位图 ---------- */
const todo = [];
for (const v of VALUES) {
  const { s } = slotOf.get(v.name);
  if (hasPlaceholder(slotPixels(s))) todo.push(`${v.text}（${v.name}）`);
}
const ledIsPlaceholder = hasPlaceholder(slotPixels(slotOf.get('led_j').s));
if (ledIsPlaceholder) todo.push('计时器的 j（led_j）');

console.log(`\n本次贴入 ${pasted} 张、复用 ${reused.length} 张${dry ? '（--dry，没有写盘）' : ''}；双曲模式共 39 张 + 1 张 j 单位`);
if (todo.length) {
  console.log(`还差 ${todo.length} 张要画（现在是占位图）：`);
  console.log('  ' + todo.join('  '));
} else {
  console.log('39 张数值贴图与 j 单位都已经是真素材了 ✓');
}
console.log('\n贴完记得跑一遍 node tools/gen_atlas.js（或直接 build.ps1）重新打包。');
