// 由 run.sh 拼接在引擎源码之后执行，所以这里可以直接用 Board / ACHIEVABLE / formatModulus 等。

// ---------- 1. 24 个可达值：化简结果与可达集合互相印证 ----------
const EXPECTED_FORMS = [
  '0', '1', '√2', '2', '√5', '2√2', '3', '√10', '√13',
  '4', '√17', '3√2', '2√5', '5', '√26', '√29', '4√2', '√34',
  '6', '√37', '2√10', '7', '5√2', '8'
];
const forms = ACHIEVABLE.map((n: number) => formatModulus(n));
if (forms.join(',') !== EXPECTED_FORMS.join(',')) {
  throw new Error('24 个可达值的化简结果不对：\n  实际 ' + forms.join(' ') + '\n  期望 ' + EXPECTED_FORMS.join(' '));
}
// 反过来：每个化简结果重新平方回去，必须等于原值
for (const n of ACHIEVABLE) {
  const s = formatModulus(n);
  const i = s.indexOf('√');
  const out = i < 0 ? parseInt(s, 10) : (i === 0 ? 1 : parseInt(s.slice(0, i), 10));
  const inside = i < 0 ? 1 : parseInt(s.slice(i + 1), 10);
  if (out * out * inside !== n) {
    throw new Error(`formatModulus(${n}) = "${s}" 化不回原值`);
  }
}
console.log('✓ 24 个可达值：' + forms.join(' '));

// ---------- 2. 随机对局：所有不变量 ----------
function neighborsOf(b: any, idx: number): number[] {
  const w = b.w;
  const r = Math.floor(idx / w);
  const c = idx % w;
  const out: number[] = [];
  for (let dr = -1; dr <= 1; dr++) {
    for (let dc = -1; dc <= 1; dc++) {
      if (dr === 0 && dc === 0) continue;
      const rr = r + dr, cc = c + dc;
      if (rr >= 0 && rr < b.h && cc >= 0 && cc < w) out.push(rr * w + cc);
    }
  }
  return out;
}

let blankCells = 0;
let cancellingZeros = 0;
let boards = 0;
let expandOk = 0;
let expandJudgeFail = 0;

function freshBoard(w: number, h: number, mines: number, seed: number, sr: number, sc: number): any {
  const b: any = new Board(w, h, mines, seed);
  b.startAt(sr, sc);
  boards++;
  return b;
}

function checkInvariants(b: any, sr: number, sc: number, mines: number): void {
  // 首击九宫格必须无雷
  for (const j of neighborsOf(b, b.index(sr, sc)).concat([b.index(sr, sc)])) {
    if (b.cells[j].mineKind >= 0) throw new Error('首击九宫格内出现了雷');
  }
  // 雷数正确
  let total = 0;
  const typeTotals = [0, 0, 0, 0];
  for (let i = 0; i < b.cells.length; i++) {
    if (b.cells[i].mineKind >= 0) {
      total++;
      typeTotals[b.cells[i].mineKind]++;
    }
  }
  if (total !== mines) throw new Error(`雷数 ${total} ≠ ${mines}`);
  for (let t = 0; t < 4; t++) {
    if (typeTotals[t] !== b.typeTotal[t]) throw new Error(`第 ${t} 种雷的公开总数算错了`);
  }

  for (let i = 0; i < b.cells.length; i++) {
    const cell = b.cells[i];
    if (cell.mineKind >= 0) continue;
    // 逐格独立重算 a、b，和引擎存的 clue 比对
    let a = 0, bb = 0, cnt = 0;
    for (const j of neighborsOf(b, i)) {
      const k = b.cells[j].mineKind;
      if (k < 0) continue;
      a += TYPES[k][0];
      bb += TYPES[k][1];
      cnt++;
    }
    if (cell.clue !== a * a + bb * bb) throw new Error(`第 ${i} 格显示值算错了`);
    if (cell.nbrMines !== cnt) throw new Error(`第 ${i} 格林雷数算错了`);
    // 显示值必须落在 24 个可达值里 —— 落了别的说明布雷/求和有问题
    if (!isAchievable(cell.clue)) throw new Error(`第 ${i} 格出现了不可达的显示值 ${cell.clue}`);
    if (cell.isBlank()) {
      blankCells++;
      if (cell.clue !== 0) throw new Error('空白格的显示值必须是 0');
    } else if (cell.clue === 0) {
      cancellingZeros++;
    }
  }
}

// 三档难度各跑一批；种子固定，任何一次失败都能原样复现
for (let s = 1; s <= 120; s++) {
  const b1 = freshBoard(9, 9, 10, s, 4, 4);
  checkInvariants(b1, 4, 4, 10);
  const b2 = freshBoard(16, 16, 40, s * 7 + 1, 8, 8);
  checkInvariants(b2, 8, 8, 40);
  const b3 = freshBoard(30, 16, 99, s * 13 + 5, 8, 15);
  checkInvariants(b3, 8, 15, 99);
}
console.log(`✓ ${boards} 局随机对局：首击九宫格安全、雷数与公开总数精确、显示值全部落在 24 个可达值内`);
console.log(`  其中空白格 ${blankCells} 个，显示 0 但周围有雷（抵消对）${cancellingZeros} 个`);
if (blankCells === 0 || cancellingZeros === 0) {
  throw new Error('空白格和抵消对必须都出现过 —— 它们的区别是这个游戏的核心');
}

// ---------- 3. 连片展开：只从空白格扩散，且绕开旗子 ----------
{
  const b = freshBoard(16, 16, 40, 4242, 8, 8);
  // 首击格必定是空白，应该连片展开一片
  const opened = b.cells.filter((c: any) => c.open).length;
  if (opened < 9) throw new Error(`首击只翻开了 ${opened} 格，连片展开没生效`);
  // 展开出来的每一格都得是安全的，而且非空白的格子不能再往外带
  for (let i = 0; i < b.cells.length; i++) {
    if (!b.cells[i].open) continue;
    if (b.cells[i].mineKind >= 0) throw new Error('连片展开炸到了雷');
  }
  console.log(`✓ 首击连片展开了 ${opened} 格，全是安全格`);
}

// ---------- 4. 主动翻开清旗，其他旗仍受连片保护 ----------
for (const mode of [MODE_COMPLEX, MODE_HYPER]) {
  for (let flag = 1; flag <= 4; flag++) {
    const first = new Board(9, 9, 10, 99, mode);
    for (let k = 0; k < flag; k++) first.cycleFlag(4, 4);
    first.cycleFlag(4, 5);
    if (first.reveal(4, 4) !== ACT_OK || !first.isStarted() || !first.cellAt(4, 4).open || first.cellAt(4, 4).flag !== 0) throw new Error('带旗首击必须清旗并安全开局');
    if (first.cellAt(4, 5).open || first.cellAt(4, 5).flag !== 1 || first.flagsTotal() !== 1) throw new Error('连片不能清除其他旗');
    for (let t = 0; t < 4; t++) if (first.unmarked(t) !== first.typeTotal[t] - (t === 0 ? 1 : 0)) throw new Error('首击计雷器不正确');
    for (const mine of [false, true]) {
      const b = new Board(9, 9, 10, 99, mode);
      b.startAt(4, 4);
      const target = b.cells.find(c => !c.open && (c.mineKind >= 0) === mine)!;
      for (let k = 0; k < flag; k++) b.cycleFlag(target.row, target.col);
      if (b.reveal(target.row, target.col) !== (mine ? ACT_BOOM : ACT_OK)) throw new Error('清旗后必须按真实雷型翻开');
      if (!target.open || target.flag !== 0 || b.flagsTotal() !== 0) throw new Error('翻开后必须清除标记');
      for (let t = 0; t < 4; t++) if (b.unmarked(t) !== b.typeTotal[t]) throw new Error('清旗后计雷器未恢复');
      if (mine) {
        if (!b.isOver() || b.isWon() || !target.exploded) throw new Error('带旗雷必须正常结算失败');
        const other = b.cells.find(c => !c.open)!;
        const before = other.flag;
        if (b.reveal(other.row, other.col) !== ACT_IGNORED || other.flag !== before) throw new Error('结算后不能清旗或翻开');
      }
    }
  }
}
console.log('✓ 两种模式×四种标记：首击清旗、安全格、踩雷、计数及其他旗保护');

// ---------- 5. 展开判定 ----------
{
  const b = freshBoard(16, 16, 40, 777, 8, 8);
  // 找一个已翻开的数字格
  let cell = -1;
  for (let i = 0; i < b.cells.length; i++) {
    if (b.cells[i].open && b.cells[i].mineKind < 0 && b.cells[i].nbrMines > 0) { cell = i; break; }
  }
  if (cell < 0) throw new Error('没找到可展开的数字格');

  // 旗子插得不对 → 判据不过，什么都不发生
  const before = b.cells.filter((x: any) => x.open).length;
  if (b.tryExpand(Math.floor(cell / b.w), cell % b.w) !== ACT_JUDGE_FAIL) {
    throw new Error('旗子插得不对时，展开判定居然过了');
  }
  if (b.cells.filter((x: any) => x.open).length !== before) {
    throw new Error('判据没过却翻开了格子');
  }
  expandJudgeFail++;

  // 把邻域的旗按真实雷型插满 → 判据必过（旗型与真值完全一致）
  for (const j of neighborsOf(b, cell)) {
    const kind = b.cells[j].mineKind;
    if (kind < 0) continue;
    b.cycleFlag(Math.floor(j / b.w), j % b.w);
    for (let k = 0; k < kind; k++) b.cycleFlag(Math.floor(j / b.w), j % b.w);
    if (b.cells[j].flag !== kind + 1) throw new Error('旗型没插到目标值');
  }
  const r2 = b.tryExpand(Math.floor(cell / b.w), cell % b.w);
  if (r2 !== ACT_OK) throw new Error(`旗子全插对时展开应当成功，实际 ${r2}`);
  const after = b.cells.filter((x: any) => x.open).length;
  if (after <= before) throw new Error('展开没有翻开任何格子');
  expandOk++;
  console.log(`✓ 展开判定：旗子不对 → 拒绝（${before} 格不变）；旗子全对 → 展开成功（${after} 格）`);
}

// ---------- 6. 结算复盘 ----------
{
  const b = freshBoard(9, 9, 10, 2024, 4, 4);
  // 插两面旗：一面插在雷上，一面插在非雷上
  let rightIdx = -1, wrongIdx = -1;
  for (let i = 0; i < b.cells.length; i++) {
    if (b.cells[i].mineKind >= 0 && rightIdx < 0 && !b.cells[i].open) rightIdx = i;
    if (b.cells[i].mineKind < 0 && wrongIdx < 0 && !b.cells[i].open) wrongIdx = i;
  }
  // 故意插成和真雷型对不上的那一种：结算只看位置，插在雷上就该算标对
  b.cycleFlag(Math.floor(rightIdx / b.w), rightIdx % b.w);
  if (b.cells[rightIdx].flag === b.cells[rightIdx].mineKind + 1) {
    b.cycleFlag(Math.floor(rightIdx / b.w), rightIdx % b.w);
  }
  b.cycleFlag(Math.floor(wrongIdx / b.w), wrongIdx % b.w);

  // 手动触发失败结算：翻一颗没插旗的雷
  // （保留已有旗帜用于验证结算标记，另选未插旗的雷作为引信）
  let mineIdx = -1;
  for (let i = 0; i < b.cells.length; i++) {
    if (b.cells[i].mineKind >= 0 && !b.cells[i].open && b.cells[i].flag === 0) { mineIdx = i; break; }
  }
  if (mineIdx < 0) throw new Error('没找到没插旗的雷');
  if (b.reveal(Math.floor(mineIdx / b.w), mineIdx % b.w) !== ACT_BOOM) {
    throw new Error('翻到雷没有返回 ACT_BOOM');
  }
  if (!b.isOver() || b.isWon()) throw new Error('踩雷后应当判负');

  if (b.cells[rightIdx].endMark !== MARK_RIGHT_FLAG) throw new Error('插在雷上的旗没有标成 MARK_RIGHT_FLAG');
  if (b.cells[wrongIdx].endMark !== MARK_WRONG_BLANK) throw new Error('插在非雷上的旗没有标成 MARK_WRONG_BLANK');
  if (b.cells[mineIdx].endMark !== MARK_NONE) throw new Error('踩中的那颗不该有复盘标记');
  if (!b.cells[mineIdx].exploded) throw new Error('踩中的那颗没标 exploded');
  // 没插旗的雷一律亮出来
  let shown = 0;
  for (let i = 0; i < b.cells.length; i++) {
    const cell = b.cells[i];
    if (cell.mineKind < 0 || cell.flag !== 0 || cell.open) continue;
    if (cell.endMark !== MARK_MINE) throw new Error('失败结算时没插旗的雷没有亮出来');
    shown++;
  }
  if (shown === 0) throw new Error('这一局应该还有没插旗的雷');
  console.log(`✓ 失败复盘：插在雷上就标绿勾（不看雷型）、插在非雷上标红叉、`
    + `${shown} 颗没插旗的雷亮出来、踩中的那颗标 exploded`);
}

// ---------- 7. 通关复盘 ----------
{
  const b = freshBoard(9, 9, 10, 31337, 4, 4);
  // 把邻域旗子按真实雷型插满，用展开判定一路推到通关
  for (let round = 0; round < 200 && !b.isOver(); round++) {
    let moved = false;
    for (let i = 0; i < b.cells.length && !b.isOver(); i++) {
      if (!b.cells[i].open || b.cells[i].mineKind >= 0) continue;
      for (const j of neighborsOf(b, i)) {
        if (b.cells[j].open || b.cells[j].mineKind < 0) continue;
        while (b.cells[j].flag !== b.cells[j].mineKind + 1) {
          b.cycleFlag(Math.floor(j / b.w), j % b.w);
        }
      }
      if (b.tryExpand(Math.floor(i / b.w), i % b.w) === ACT_OK) moved = true;
    }
    if (!moved) break;
  }
  if (!b.isWon()) throw new Error('按真实雷型插满旗后一路展开，应该能通关');
  // 通关时所有非雷格都翻开了，留在场上的旗必然都在雷上
  for (let i = 0; i < b.cells.length; i++) {
    const cell = b.cells[i];
    if (cell.flag === 0) continue;
    if (cell.mineKind < 0) throw new Error('通关时还有旗插在非雷格上');
    if (cell.endMark !== MARK_RIGHT_FLAG) throw new Error('通关时插对的旗没标成 MARK_RIGHT_FLAG');
  }
  console.log('✓ 通关复盘：所有留下的旗都在雷上，全部标成绿勾');
}

// ---------- 8. 通关时没插旗的雷也亮出来 ----------
{
  const b = freshBoard(9, 9, 10, 606, 4, 4);
  // 只插一面旗，而且故意插成和真雷型对不上的那种，其余雷都不插
  let flagged = -1;
  for (let i = 0; i < b.cells.length; i++) {
    if (b.cells[i].mineKind >= 0) {
      flagged = i;
      break;
    }
  }
  b.cycleFlag(Math.floor(flagged / b.w), flagged % b.w);
  if (b.cells[flagged].flag === b.cells[flagged].mineKind + 1) {
    b.cycleFlag(Math.floor(flagged / b.w), flagged % b.w);
  }
  // 直接翻开所有非雷格 → 通关
  for (let i = 0; i < b.cells.length && !b.isOver(); i++) {
    if (b.cells[i].mineKind < 0 && !b.cells[i].open) {
      b.reveal(Math.floor(i / b.w), i % b.w);
    }
  }
  if (!b.isWon()) throw new Error('翻开所有非雷格后应当通关');
  if (b.cells[flagged].endMark !== MARK_RIGHT_FLAG) throw new Error('通关时插在雷上的旗没有标成 MARK_RIGHT_FLAG');
  let shown = 0;
  for (let i = 0; i < b.cells.length; i++) {
    const cell = b.cells[i];
    if (cell.mineKind < 0 || cell.flag !== 0) continue;
    if (cell.endMark !== MARK_MINE) throw new Error('通关时没插旗的雷没有亮出来');
    shown++;
  }
  if (shown === 0) throw new Error('这一局应该还有没插旗的雷');
  console.log(`✓ 通关复盘：插旗的雷只看位置标绿勾，另外 ${shown} 颗没插旗的雷也亮出来了`);
}

// ---------- 8. 三档难度 ----------
for (const d of DIFFICULTIES) {
  const b: any = new Board(d.w, d.h, d.mines, 5);
  b.startAt(Math.floor(d.h / 2), Math.floor(d.w / 2));
  let n = 0;
  for (let i = 0; i < b.cells.length; i++) if (b.cells[i].mineKind >= 0) n++;
  console.log(`  ${d.label} ${d.w}×${d.h} · ${d.mines} 雷 → 实际 ${n} 颗`);
}

// 首击与动作边界，和 Swift / Kotlin 同步。
{
  const b = new Board(9, 9, 10, 1);
  b.cycleFlag(4, 4);
  b.startAt(4, 4);
  if (b.isStarted()) throw new Error('带旗首击不能布雷');
  if (b.reveal(4, 4) !== ACT_OK || !b.isStarted() || b.mineTotal() !== 10) throw new Error('带旗 reveal 应清旗并正常布雷开局');
  if (b.cellAt(4, 4).flag !== 0 || b.flagsTotal() !== 0) throw new Error('首击必须归还旗数');
  const snapshot = JSON.stringify(b.cells);
  b.startAt(0, 0);
  if (snapshot !== JSON.stringify(b.cells)) throw new Error('重复 startAt 不能重布雷');
  for (const [r, c] of [[-1, 0], [0, -1], [9, 0], [0, 9]]) {
    if (b.reveal(r, c) !== ACT_IGNORED || b.tryExpand(r, c) !== ACT_IGNORED || b.cycleFlag(r, c)) throw new Error('越界动作必须忽略');
    b.startAt(r, c);
  }
  console.log('✓ 带旗直接开局、重复开局与越界动作');
}
{
  const b = new Board(3, 3, 0, 1);
  if (b.reveal(1, 1) !== ACT_OK || !b.isWon() || !b.cells.every(c => c.open)) throw new Error('首击开完所有安全格必须立即通关');
  if (b.cycleFlag(0, 0)) throw new Error('结束后不能继续插旗');
  console.log('✓ 首击即可通关并冻结棋盘');
}
{
  const cases: [number, number, number, number, number, number, string][] = [
    [9, 9, 10, 1, 4, 4, 'e89c77c9'],
    [16, 16, 40, 8, 8, 8, 'd9ca35a9'],
    [30, 16, 99, 5, 8, 15, '04680c3c'],
    [9, 9, 10, 2024, 0, 0, 'b5649eeb'],
    [16, 16, 40, 31337, 15, 15, '5c1eb7a8'],
    [30, 16, 99, 123456, 0, 29, 'd7ac09af']
  ];
  for (const [w, h, mines, seed, sr, sc, expected] of cases) {
    const b = new Board(w, h, mines, seed);
    b.startAt(sr, sc);
    const parts = b.cells.map(c => `${c.mineKind + 1},${c.clue},${c.nbrMines},${c.open ? 1 : 0}`);
    for (let t = 0; t < 4; t++) parts.push(`T${b.typeTotal[t]},${b.unmarked(t)}`);
    parts.push(`over${b.isOver()}won${b.isWon()}`);
    let hash = 0x811c9dc5;
    for (const ch of parts.join(';')) hash = Math.imul(hash ^ ch.charCodeAt(0), 0x01000193) >>> 0;
    const got = hash.toString(16).padStart(8, '0');
    if (got !== expected) throw new Error(`棋盘指纹不一致：${got}，期望 ${expected}`);
  }
  console.log('✓ 6 个固定种子的棋盘指纹与 Swift / Kotlin 逐位一致');
}

// 新模式：独立枚举符号等价关系，验证实际棋盘与展开实现。
{
  const combos: number[][] = [];
  const values = new Set<number>();
  for (let p=0;p<=8;p++) for(let n=0;n<=8-p;n++)
    for(let j=0;j<=8-p-n;j++) for(let k=0;k<=8-p-n-j;k++) {
      combos.push([p,n,j,k]); values.add((p-n)**2-(j-k)**2);
    }
  if (combos.length !== 495 || [...values].sort((a,b)=>a-b).join() !== HYPER_ACHIEVABLE.join()) throw Error('39 个双曲显示值覆盖不全');
  if(formatClue(-1)!=='i'||formatClue(-12)!=='2√3i'||formatClue(0)!=='0') throw Error('负显示值格式错误');
  let checks=0, negative=0, lightlike=0;
  for(const d of DIFFICULTIES) for(let seed=1;seed<=120;seed++) {
    const b: any = new Board(d.w,d.h,d.mines,seed,MODE_HYPER);
    b.startAt(Math.floor(d.h/2),Math.floor(d.w/2));
    for(let i=0;i<b.cells.length;i++) {
      const c=b.cells[i]; if(c.mineKind>=0) continue;
      let a=0,j=0,count=0;
      for(const n of neighborsOf(b,i)) if(b.cells[n].mineKind>=0) {
        const t=TYPES[b.cells[n].mineKind]; a+=t[0];j+=t[1];count++;
      }
      if(c.clue !== a*a-j*j || c.nbrMines!==count || !values.has(c.clue)) throw Error('双曲整数显示值不一致');
      if(c.clue<0) negative++;
      if(c.clue===0 && count>0) {lightlike++;if(c.isBlank())throw Error('光锥零被当成空白');}
    }
    const center=b.cells.findIndex((c: any,i: number)=>c.mineKind<0 && c.nbrMines>0 && neighborsOf(b,i).length===8);
    if(center<0) throw Error('测试邻域缺失');
    const ns=neighborsOf(b,center);let ta=0,tb=0,nt=0;
    for(const n of ns) if(b.cells[n].mineKind>=0) {const t=TYPES[b.cells[n].mineKind];ta+=t[0];tb+=t[1];nt++;}
    for(const cc of combos) {
      const flags=cc.flatMap((n: number,t: number)=>Array(n).fill(t+1));
      for(let i=0;i<8;i++)b.cells[ns[i]].flag=flags[i]??0;
      const fa=cc[0]-cc[1],fb=cc[2]-cc[3];
      const expected=flags.length===nt && [[ta,tb],[-ta,tb],[ta,-tb],[-ta,-tb]].some(([a,j])=>a===fa&&j===fb);
      if(b.matchComboTruth(center)!==expected) throw Error('双曲展开错误');checks++;
    }
  }
  if(negative===0||lightlike===0)throw Error('未覆盖负值或非空白零');
  console.log(`✓ 双曲 360 局、39 显示值、${checks} 次展开判据、负值与非空白零`);
  const cases = [[9, 9, 10, 1, 4, 4, "1a6bf9f4"], [16, 16, 40, 8, 8, 8, "4759fc78"], [30, 16, 99, 5, 8, 15, "37233296"], [9, 9, 10, 2024, 0, 0, "a0ef92af"], [16, 16, 40, 31337, 15, 15, "7b20fba3"], [30, 16, 99, 123456, 0, 29, "8de13a32"]];
  for(const [w,h,m,s,r,c,expected] of cases) {
    const b=new Board(w,h,m,s,MODE_HYPER);b.startAt(r,c);
    const parts=b.cells.map(c=>`${c.mineKind+1},${c.clue},${c.nbrMines},${c.open?1:0}`);
    for(let t=0;t<4;t++)parts.push(`T${b.typeTotal[t]},${b.unmarked(t)}`);
    parts.push(`over${b.isOver()}won${b.isWon()}`);let hash=0x811c9dc5;
    for(const ch of parts.join(';'))hash=Math.imul(hash^ch.charCodeAt(0),0x01000193)>>>0;
    if(hash.toString(16).padStart(8,'0')!==expected)throw Error('双曲固定种子指纹错误');
  }
  console.log('✓ 双曲 6 组参考指纹通过');
}
