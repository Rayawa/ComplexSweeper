// 由 run.sh 拼接在引擎源码之后执行。
//
// 目的：没有真机时也能看见界面长什么样。棋盘由真实的引擎跑出来，
// 贴图直接用 entry/src/main/resources/base/media 里那批切好的 PNG，
// 排版尺寸逐条对应 Index.ets —— 所以预览不会跟真实界面走样。
// 它验不了 ArkUI 的运行时行为（手势、@ObjectLink 刷新、HdsNavigation），只能验排版和观感。

import * as fs from 'node:fs';
import * as path from 'node:path';

const PROJECT = process.argv[2];
const OUT_DIR = process.argv[3];
const MEDIA = path.join(PROJECT, 'entry/src/main/resources/base/media');

const PAGE_W = 360;
// 与 Index.ets 的 edge() 同一条公式：按实测宽度压到放得下，再夹到 [16,36]
const PAGE_PAD = 8;
const BOARD_PANEL = 12;   // 面板左右各 3 内边距 + 3 边框
function edgeFor(cols: number): number {
  const areaW = PAGE_W - 2 * PAGE_PAD;
  const boardAreaW = areaW - 8;
  const fits = Math.floor((boardAreaW - 10) / cols);
  return Math.min(Math.max(fits, 16), 36);
}
const LED_W = 13;
const ICON = 18;
const FACE = 46;

/** 底栏标签：三档难度 + 关于（真实界面里「关于」在标题栏，预览图省事画进底栏） */
const TAB_NAMES: string[] = ['初级', '中级', '高级', '关于'];

function dataUri(name: string): string {
  const b = fs.readFileSync(path.join(MEDIA, `${name}.png`));
  return `data:image/png;base64,${b.toString('base64')}`;
}

const IMG: Record<string, string> = {};
function img(name: string): string {
  if (!IMG[name]) {
    IMG[name] = dataUri(name);
  }
  return IMG[name];
}

/** 数字贴图：下标是 a²+b²，只有 24 个可达值有图 */
function numName(clue: number): string {
  return `cw_num_${clue}`;
}
function nameOf(list: string[], t: number): string {
  return list[Math.min(Math.max(t, 1), 4) - 1];
}
const FLAG = ['cw_flag_1', 'cw_flag_2', 'cw_flag_3', 'cw_flag_4'];
const MINE = ['cw_mine_1', 'cw_mine_2', 'cw_mine_3', 'cw_mine_4'];
const BOOM = ['cw_boom_1', 'cw_boom_2', 'cw_boom_3', 'cw_boom_4'];
const WRONG = ['cw_wrong_1', 'cw_wrong_2', 'cw_wrong_3', 'cw_wrong_4'];
const RIGHT = ['cw_right_1', 'cw_right_2', 'cw_right_3', 'cw_right_4'];
const RIGHTFLAG = ['cw_rightflag_1', 'cw_rightflag_2', 'cw_rightflag_3', 'cw_rightflag_4'];
const WRONGFLAG = ['cw_wrongflag_1', 'cw_wrongflag_2', 'cw_wrongflag_3', 'cw_wrongflag_4'];
const FACE_NAMES = ['cw_face_down', 'cw_face_scan', 'cw_face_dead', 'cw_face_win', 'cw_face_normal'];

// ---------------- 造一个像样的局面 ----------------

function play(diffIndex: number, progress: number, outcome: string) {
  const d = DIFFICULTIES[diffIndex];
  const b: any = new Board(d.w, d.h, d.mines, 20251008);
  b.startAt(Math.floor(d.h / 2), Math.floor(d.w / 2));

  // 多翻一些，模拟玩家推进
  const target = Math.floor(b.cells.length * progress);
  for (let i = 0; i < b.cells.length && !b.isOver(); i++) {
    let opened = 0;
    for (let k = 0; k < b.cells.length; k++) if (b.cells[k].open) opened++;
    if (opened >= target) break;
    if (!b.cells[i].open && b.cells[i].mineKind < 0) {
      b.reveal(Math.floor(i / b.w), i % b.w);
    }
  }

  if (outcome === 'lost') {
    // 故意插两面旗：一面插对，一面插在非雷上；再踩一颗雷收场
    let okIdx = -1, badIdx = -1;
    for (let i = 0; i < b.cells.length; i++) {
      const c = b.cells[i];
      if (c.open) continue;
      if (c.mineKind >= 0 && okIdx < 0) okIdx = i;
      if (c.mineKind < 0 && badIdx < 0) badIdx = i;
    }
    if (okIdx >= 0) for (let k = 0; k <= b.cells[okIdx].mineKind; k++) b.cycleFlag(Math.floor(okIdx / b.w), okIdx % b.w);
    if (badIdx >= 0) b.cycleFlag(Math.floor(badIdx / b.w), badIdx % b.w);
    for (let i = 0; i < b.cells.length; i++) {
      const c = b.cells[i];
      if (c.mineKind >= 0 && !c.open && c.flag === 0) {
        b.reveal(Math.floor(i / b.w), i % b.w);
        break;
      }
    }
  } else if (outcome === 'won') {
    // 按真实雷型插满旗，再用展开判定一路推平
    for (let round = 0; round < 300 && !b.isOver(); round++) {
      let moved = false;
      for (let i = 0; i < b.cells.length && !b.isOver(); i++) {
        const c = b.cells[i];
        if (!c.open || c.mineKind >= 0) continue;
        for (let j = 0; j < b.cells.length; j++) {
          const n = b.cells[j];
          if (n.open || n.mineKind < 0) continue;
          const r = Math.floor(i / b.w), cc = i % b.w;
          const dr = Math.abs(Math.floor(j / b.w) - r), dc = Math.abs((j % b.w) - cc);
          if (dr > 1 || dc > 1) continue;
          while (n.flag !== n.mineKind + 1) b.cycleFlag(Math.floor(j / b.w), j % b.w);
        }
        if (b.tryExpand(Math.floor(i / b.w), i % b.w) === ACT_OK) moved = true;
      }
      if (!moved) break;
    }
  } else {
    // 中局随手插几面旗，四种都露个脸
    let placed = 0;
    for (let i = 0; i < b.cells.length && placed < 4; i++) {
      const c = b.cells[i];
      if (!c.open && c.mineKind >= 0) {
        for (let k = 0; k <= placed; k++) b.cycleFlag(Math.floor(i / b.w), i % b.w);
        placed++;
      }
    }
  }
  return b;
}

// ---------------- 渲染 ----------------

function cellImg(b: any, i: number): string {
  const c = b.cells[i];
  const kind = c.mineKind + 1;
  let name = 'cw_closed';
  if (c.open) {
    if (c.mineKind >= 0) {
      name = c.exploded ? BOOM[kind - 1] : MINE[kind - 1];
    } else if (c.isBlank()) {
      name = 'cw_blank';
    } else {
      name = numName(c.clue);
    }
  } else if (c.endMark === MARK_WRONG_BLANK) {
    name = 'cw_wrongblank';
  } else if (c.endMark === MARK_WRONG) {
    name = WRONG[kind - 1];
  } else if (c.endMark === MARK_RIGHT) {
    name = RIGHT[kind - 1];
  } else if (c.endMark === MARK_RIGHT_FLAG) {
    name = RIGHTFLAG[kind - 1];
  } else if (c.endMark === MARK_WRONG_FLAG) {
    name = WRONGFLAG[(kind !== 0 ? kind : c.flag) - 1];
  } else if (c.endMark === MARK_MINE) {
    name = MINE[kind - 1];
  } else if (c.flag > 0) {
    name = FLAG[c.flag - 1];
  }
  return `<img class="cell" src="${img(name)}">`;
}

/** 数码管的一排格子：0..9 数字、10 负号、11 i 单位、12 空格 */
function ledCodes(value: number, slots: number, imagUnit: boolean, blankAll: boolean): number[] {
  const out: number[] = [];
  for (let i = 0; i < slots; i++) out.push(12);
  if (blankAll) return out;
  const digitSlots = imagUnit ? slots - 1 : slots;
  const negative = value < 0;
  let rest = Math.abs(Math.round(value));
  let pos = digitSlots - 1;
  while (pos >= 0) {
    out[pos] = rest % 10;
    rest = Math.floor(rest / 10);
    if (rest === 0) break;
    pos--;
  }
  if (negative && pos - 1 >= 0) out[pos - 1] = 10;
  if (imagUnit) out[slots - 1] = 11;
  return out;
}

function ledHtml(codes: number[]): string {
  const cells = codes.map((c) => {
    const n = c <= 9 ? `cw_led_${c}` : (c === 10 ? 'cw_led_minus' : (c === 11 ? 'cw_led_i' : 'cw_led_blank'));
    return `<img class="ledcell" src="${img(n)}">`;
  }).join('');
  return `<div class="led">${cells}</div>`;
}

function screen(opts: any): string {
  const d = DIFFICULTIES[opts.diffIndex];
  const EDGE = edgeFor(d.w);
  const b = play(opts.diffIndex, opts.progress, opts.outcome);
  const started = b.isStarted();
  const over = b.isOver();
  const won = b.isWon();
  const elapsed = opts.elapsed;

  const counters = [0, 1, 2, 3].map((t) => {
    const k = b.unmarked(t);
    const v = (t === 1 || t === 3) ? -k : k;
    return `<div class="counter">
      <img class="icon" src="${img(FLAG[t])}">
      ${ledHtml(ledCodes(v, 4, t >= 2, !started))}
    </div>`;
  }).join('');

  const faceKind = over ? (won ? 3 : 2) : 4;
  const cells = b.cells.map((_: any, i: number) => cellImg(b, i)).join('');

  const status = over
    ? (won ? `通关！用时 ${elapsed} 秒` : `踩雷了 · 用时 ${elapsed} 秒 · 绿勾标对，红叉标错`)
    : (started ? '单击标记 · 长按翻开 · 点数字格可展开' : '长按翻开第一格 · 四种雷的数量开局后公布');

  return `<!doctype html><html><head><meta charset="utf-8"><style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{width:${PAGE_W}px;background:#C0C0C0;font-family:-apple-system,'HarmonyOS Sans SC','PingFang SC',sans-serif;
       display:flex;flex-direction:column;padding:8px 8px 4px}
  .titlebar{height:52px;display:flex;align-items:center;padding:0 16px;
            background:#F1F3F5;border-bottom:1px solid #D8DCE1;margin:-8px -8px 8px}
  .titlebar b{font-size:17px;color:#000}
  .header{display:flex;align-items:center;padding:6px;background:#C0C0C0;
          border-top:3px solid #808080;border-left:3px solid #808080;
          border-bottom:3px solid #FFFFFF;border-right:3px solid #FFFFFF}
  .counters{display:flex;flex-direction:column}
  .counter{display:flex;align-items:center;padding:0 2px}
  .icon{width:${ICON}px;height:${ICON}px;image-rendering:pixelated}
  .led{display:flex;background:#000;padding:2px}
  .ledcell{width:${LED_W}px;height:${Math.round(LED_W * 23 / 13)}px;image-rendering:pixelated}
  .spacer{flex:1}
  .right{display:flex;flex-direction:column;align-items:center;gap:6px}
  .face{width:${FACE}px;height:${FACE}px;image-rendering:pixelated}
  .boardwrap{margin-top:8px;padding:3px;background:#C0C0C0;
             border-top:3px solid #808080;border-left:3px solid #808080;
             border-bottom:3px solid #FFFFFF;border-right:3px solid #FFFFFF;
             overflow:hidden}
  .grid{display:flex;flex-wrap:wrap;width:${d.w * EDGE}px}
  .cell{width:${EDGE}px;height:${EDGE}px;image-rendering:pixelated;display:block}
  .status{font-size:12px;color:#000;text-align:center;padding:6px 0 2px}
  .toolbar{margin-top:8px;height:52px;display:flex;align-items:center;justify-content:space-around;
           background:#F1F3F5;border-top:1px solid #D8DCE1;margin-left:-8px;margin-right:-8px}
  .toolbar span{font-size:12px;color:#000}
  .toolbar span.on{color:#0A59F7}
  </style></head><body>
  <div class="titlebar"><b>复扫雷</b></div>
  <div class="header">
    <div class="counters">${counters}</div>
    <div class="spacer"></div>
    <div class="right">
      <img class="face" src="${img(FACE_NAMES[faceKind])}">
      ${ledHtml(ledCodes(elapsed, 4, false, false))}
    </div>
    <div class="spacer"></div>
  </div>
  <div class="boardwrap"><div class="grid">${cells}</div></div>
  <div class="status">${status}</div>
  <div class="toolbar">${TAB_NAMES.map((n, i) =>
      `<span${i === opts.diffIndex ? ' class="on"' : ''}>${n}</span>`).join('')}</div>
  </body></html>`;
}

const SCREENS: any[] = [
  { name: '01-easy-play', diffIndex: 0, progress: 0.55, outcome: 'play', elapsed: 37 },
  { name: '02-medium-play', diffIndex: 1, progress: 0.60, outcome: 'play', elapsed: 214 },
  { name: '03-hard-play', diffIndex: 2, progress: 0.45, outcome: 'play', elapsed: 611 },
  { name: '04-lost', diffIndex: 1, progress: 0.70, outcome: 'lost', elapsed: 188 },
  { name: '05-won', diffIndex: 0, progress: 1.0, outcome: 'won', elapsed: 41 }
];

fs.mkdirSync(OUT_DIR, { recursive: true });
for (const s of SCREENS) {
  fs.writeFileSync(path.join(OUT_DIR, `${s.name}.html`), screen(s));
}
console.log(`已生成 ${SCREENS.length} 张界面预览到 ${OUT_DIR}`);
