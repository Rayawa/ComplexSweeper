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

// ---------- 4. 旗子保护格子 ----------
{
  const b = freshBoard(9, 9, 10, 99, 4, 4);
  let target = -1;
  for (let i = 0; i < b.cells.length; i++) {
    if (!b.cells[i].open && b.cells[i].mineKind < 0) { target = i; break; }
  }
  const r = Math.floor(target / b.w), c = target % b.w;
  b.cycleFlag(r, c);
  if (b.cells[target].flag !== 1) throw new Error('插旗失败');
  const act = b.reveal(r, c);
  if (act !== ACT_IGNORED) throw new Error('插了旗的格子居然被翻开了');
  if (b.cells[target].open) throw new Error('插了旗的格子还是被翻开了');
  // 循环一圈回到空
  for (let k = 0; k < 4; k++) b.cycleFlag(r, c);
  if (b.cells[target].flag !== 0) throw new Error('旗子循环没有回到空');
  if (b.unmarked(0) !== b.typeTotal[0]) throw new Error('清旗后计数没还原');
  console.log('✓ 旗子保护格子；循环一圈 空 → +1 → -1 → +i → -i → 空');
}

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
  // （插了旗的雷翻不开，那是旗子在保护格子，这里不能拿它当引信）
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
