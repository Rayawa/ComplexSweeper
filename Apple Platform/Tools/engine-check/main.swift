// 引擎逻辑校验。
//
// 由 run.sh 把引擎源码和这个文件一起交给 swiftc 编译执行 —— 所以这里不需要
// import，直接用 Board / Cell / kAchievable / formatModulus 等。
//
// 逐条对应 HarmonyOS 版 scripts/engine-check/engine.test.ts：两边跑的是同一套
// 断言、同一批固定种子，任何一个平台的引擎跑偏了都会在这里炸出来。

import Foundation
import Observation

var failed = 0

func check(_ condition: Bool, _ message: String) {
    if condition { return }
    failed += 1
    FileHandle.standardError.write("✗ \(message)\n".data(using: .utf8)!)
}

// ---------- 1. 24 个可达值：化简结果与可达集合互相印证 ----------

let expectedForms = [
    "0", "1", "√2", "2", "√5", "2√2", "3", "√10", "√13",
    "4", "√17", "3√2", "2√5", "5", "√26", "√29", "4√2", "√34",
    "6", "√37", "2√10", "7", "5√2", "8",
]
let forms = kAchievable.map { formatModulus($0) }
check(forms == expectedForms,
      "24 个可达值的化简结果不对：\n  实际 \(forms.joined(separator: " "))\n  期望 \(expectedForms.joined(separator: " "))")

// 反过来：每个化简结果重新平方回去，必须等于原值
for n in kAchievable {
    let s = formatModulus(n)
    let parts = s.split(separator: "√", omittingEmptySubsequences: false).map(String.init)
    let outside = parts.count == 1 ? (Int(parts[0]) ?? -1) : (parts[0].isEmpty ? 1 : (Int(parts[0]) ?? -1))
    let inside = parts.count == 1 ? 1 : (Int(parts[1]) ?? -1)
    check(outside * outside * inside == n, "formatModulus(\(n)) = \"\(s)\" 化不回原值")
}
print("✓ 24 个可达值：" + forms.joined(separator: " "))

// ---------- 2. 随机对局：所有不变量 ----------

func neighborsOf(_ b: Board, _ idx: Int) -> [Int] {
    let w = b.w
    let r = idx / w
    let c = idx % w
    var out: [Int] = []
    for dr in -1...1 {
        for dc in -1...1 {
            if dr == 0 && dc == 0 { continue }
            let rr = r + dr
            let cc = c + dc
            if rr >= 0 && rr < b.h && cc >= 0 && cc < w { out.append(rr * w + cc) }
        }
    }
    return out
}

var blankCells = 0
var cancellingZeros = 0
var boards = 0

func freshBoard(_ w: Int, _ h: Int, _ mines: Int, _ seed: Int, _ sr: Int, _ sc: Int) -> Board {
    let b = Board(w: w, h: h, mines: mines, seed: seed)
    b.startAt(sr, sc)
    boards += 1
    return b
}

func checkInvariants(_ b: Board, _ sr: Int, _ sc: Int, _ mines: Int) {
    // 首击九宫格必须无雷
    for j in neighborsOf(b, b.index(sr, sc)) + [b.index(sr, sc)] where b.cells[j].mineKind >= 0 {
        check(false, "首击九宫格内出现了雷")
        return
    }
    // 雷数正确
    var total = 0
    var typeTotals = [0, 0, 0, 0]
    for cell in b.cells where cell.mineKind >= 0 {
        total += 1
        typeTotals[cell.mineKind] += 1
    }
    check(total == mines, "雷数 \(total) ≠ \(mines)")
    for t in 0..<4 {
        check(typeTotals[t] == b.typeTotal[t], "第 \(t) 种雷的公开总数算错了")
    }

    for i in 0..<b.cells.count {
        let cell = b.cells[i]
        if cell.mineKind >= 0 { continue }
        // 逐格独立重算 a、b，和引擎存的 clue 比对
        var a = 0
        var bb = 0
        var cnt = 0
        for j in neighborsOf(b, i) {
            let k = b.cells[j].mineKind
            if k < 0 { continue }
            a += kMineTypes[k].re
            bb += kMineTypes[k].im
            cnt += 1
        }
        check(cell.clue == a * a + bb * bb, "第 \(i) 格显示值算错了")
        check(cell.nbrMines == cnt, "第 \(i) 格林雷数算错了")
        // 显示值必须落在 24 个可达值里 —— 落了别的说明布雷/求和有问题
        check(isAchievable(cell.clue), "第 \(i) 格出现了不可达的显示值 \(cell.clue)")
        if cell.isBlank {
            blankCells += 1
            check(cell.clue == 0, "空白格的显示值必须是 0")
        } else if cell.clue == 0 {
            cancellingZeros += 1
        }
    }
}

// 三档难度各跑一批；种子固定，任何一次失败都能原样复现
for s in 1...120 {
    checkInvariants(freshBoard(9, 9, 10, s, 4, 4), 4, 4, 10)
    checkInvariants(freshBoard(16, 16, 40, s * 7 + 1, 8, 8), 8, 8, 40)
    checkInvariants(freshBoard(30, 16, 99, s * 13 + 5, 8, 15), 8, 15, 99)
}
print("✓ \(boards) 局随机对局：首击九宫格安全、雷数与公开总数精确、显示值全部落在 24 个可达值内")
print("  其中空白格 \(blankCells) 个，显示 0 但周围有雷（抵消对）\(cancellingZeros) 个")
check(blankCells > 0 && cancellingZeros > 0,
      "空白格和抵消对必须都出现过 —— 它们的区别是这个游戏的核心")

// ---------- 3. 连片展开：只从空白格扩散，且绕开旗子 ----------
do {
    let b = freshBoard(16, 16, 40, 4242, 8, 8)
    // 首击格必定是空白，应该连片展开一片
    let opened = b.cells.filter { $0.isOpen }.count
    check(opened >= 9, "首击只翻开了 \(opened) 格，连片展开没生效")
    // 展开出来的每一格都得是安全的
    for cell in b.cells where cell.isOpen {
        check(cell.mineKind < 0, "连片展开炸到了雷")
        break
    }
    print("✓ 首击连片展开了 \(opened) 格，全是安全格")
}

// ---------- 4. 旗子保护格子 ----------
do {
    let b = freshBoard(9, 9, 10, 99, 4, 4)
    var target = -1
    for i in 0..<b.cells.count where !b.cells[i].isOpen && b.cells[i].mineKind < 0 {
        target = i
        break
    }
    check(target >= 0, "没找到可插旗的非雷格")
    let r = target / b.w
    let c = target % b.w
    b.cycleFlag(r, c)
    check(b.cells[target].flag == 1, "插旗失败")
    let act = b.reveal(r, c)
    check(act == ACT_IGNORED, "插了旗的格子居然被翻开了")
    check(!b.cells[target].isOpen, "插了旗的格子还是被翻开了")
    // 循环一圈回到空
    for _ in 0..<4 { b.cycleFlag(r, c) }
    check(b.cells[target].flag == 0, "旗子循环没有回到空")
    check(b.unmarked(0) == b.typeTotal[0], "清旗后计数没还原")
    print("✓ 旗子保护格子；循环一圈 空 → +1 → -1 → +i → -i → 空")
}

// ---------- 5. 展开判定 ----------
do {
    let b = freshBoard(16, 16, 40, 777, 8, 8)
    // 找一个已翻开的数字格
    var cell = -1
    for i in 0..<b.cells.count where b.cells[i].isOpen && b.cells[i].mineKind < 0 && b.cells[i].nbrMines > 0 {
        cell = i
        break
    }
    check(cell >= 0, "没找到可展开的数字格")

    // 旗子插得不对 → 判据不过，什么都不发生
    let before = b.cells.filter { $0.isOpen }.count
    check(b.tryExpand(cell / b.w, cell % b.w) == ACT_JUDGE_FAIL,
          "旗子插得不对时，展开判定居然过了")
    check(b.cells.filter { $0.isOpen }.count == before, "判据没过却翻开了格子")

    // 把邻域的旗按真实雷型插满 → 判据必过（旗型与真值完全一致）
    for j in neighborsOf(b, cell) {
        let kind = b.cells[j].mineKind
        if kind < 0 { continue }
        b.cycleFlag(j / b.w, j % b.w)
        for _ in 0..<kind { b.cycleFlag(j / b.w, j % b.w) }
        check(b.cells[j].flag == kind + 1, "旗型没插到目标值")
    }
    let r2 = b.tryExpand(cell / b.w, cell % b.w)
    check(r2 == ACT_OK, "旗子全插对时展开应当成功，实际 \(r2)")
    let after = b.cells.filter { $0.isOpen }.count
    check(after > before, "展开没有翻开任何格子")
    print("✓ 展开判定：旗子不对 → 拒绝（\(before) 格不变）；旗子全对 → 展开成功（\(after) 格）")
}

// ---------- 6. 失败结算复盘 ----------
do {
    let b = freshBoard(9, 9, 10, 2024, 4, 4)
    // 插两面旗：一面插在雷上，一面插在非雷上
    var rightIdx = -1
    var wrongIdx = -1
    for i in 0..<b.cells.count {
        if b.cells[i].mineKind >= 0 && rightIdx < 0 && !b.cells[i].isOpen { rightIdx = i }
        if b.cells[i].mineKind < 0 && wrongIdx < 0 && !b.cells[i].isOpen { wrongIdx = i }
    }
    check(rightIdx >= 0 && wrongIdx >= 0, "没找到可插旗的雷/非雷")
    // 故意插成和真雷型对不上的那一种：结算只看位置，插在雷上就该算标对
    b.cycleFlag(rightIdx / b.w, rightIdx % b.w)
    if b.cells[rightIdx].flag == b.cells[rightIdx].mineKind + 1 {
        b.cycleFlag(rightIdx / b.w, rightIdx % b.w)
    }
    b.cycleFlag(wrongIdx / b.w, wrongIdx % b.w)

    // 手动触发失败结算：翻一颗没插旗的雷
    // （插了旗的雷翻不开，那是旗子在保护格子，这里不能拿它当引信）
    var mineIdx = -1
    for i in 0..<b.cells.count where b.cells[i].mineKind >= 0 && !b.cells[i].isOpen && b.cells[i].flag == 0 {
        mineIdx = i
        break
    }
    check(mineIdx >= 0, "没找到没插旗的雷")
    check(b.reveal(mineIdx / b.w, mineIdx % b.w) == ACT_BOOM, "翻到雷没有返回 ACT_BOOM")
    check(b.isOver() && !b.isWon(), "踩雷后应当判负")

    check(b.cells[rightIdx].endMark == MARK_RIGHT_FLAG, "插在雷上的旗没有标成 MARK_RIGHT_FLAG")
    check(b.cells[wrongIdx].endMark == MARK_WRONG_BLANK, "插在非雷上的旗没有标成 MARK_WRONG_BLANK")
    check(b.cells[mineIdx].endMark == MARK_NONE, "踩中的那颗不该有复盘标记")
    check(b.cells[mineIdx].exploded, "踩中的那颗没标 exploded")
    // 没插旗的雷一律亮出来
    var shown = 0
    for cell in b.cells {
        if cell.mineKind < 0 || cell.flag != 0 || cell.isOpen { continue }
        check(cell.endMark == MARK_MINE, "失败结算时没插旗的雷没有亮出来")
        shown += 1
    }
    check(shown > 0, "这一局应该还有没插旗的雷")
    print("✓ 失败复盘：插在雷上就标绿勾（不看雷型）、插在非雷上标红叉、"
          + "\(shown) 颗没插旗的雷亮出来、踩中的那颗标 exploded")
}

// ---------- 7. 通关复盘 ----------
do {
    let b = freshBoard(9, 9, 10, 31337, 4, 4)
    // 把邻域旗子按真实雷型插满，用展开判定一路推到通关
    var round = 0
    while round < 200 && !b.isOver() {
        var moved = false
        for i in 0..<b.cells.count {
            if b.isOver() { break }
            if !b.cells[i].isOpen || b.cells[i].mineKind >= 0 { continue }
            for j in neighborsOf(b, i) {
                if b.cells[j].isOpen || b.cells[j].mineKind < 0 { continue }
                var guardCount = 0
                while b.cells[j].flag != b.cells[j].mineKind + 1 && guardCount < 8 {
                    b.cycleFlag(j / b.w, j % b.w)
                    guardCount += 1
                }
            }
            if b.tryExpand(i / b.w, i % b.w) == ACT_OK { moved = true }
        }
        if !moved { break }
        round += 1
    }
    check(b.isWon(), "按真实雷型插满旗后一路展开，应该能通关")
    // 通关时所有非雷格都翻开了，留在场上的旗必然都在雷上
    for cell in b.cells where cell.flag != 0 {
        check(cell.mineKind >= 0, "通关时还有旗插在非雷格上")
        check(cell.endMark == MARK_RIGHT_FLAG, "通关时插对的旗没标成 MARK_RIGHT_FLAG")
    }
    print("✓ 通关复盘：所有留下的旗都在雷上，全部标成绿勾")
}

// ---------- 8. 通关时没插旗的雷也亮出来 ----------
do {
    let b = freshBoard(9, 9, 10, 606, 4, 4)
    // 只插一面旗，而且故意插成和真雷型对不上的那种，其余雷都不插
    var flagged = -1
    for i in 0..<b.cells.count where b.cells[i].mineKind >= 0 {
        flagged = i
        break
    }
    check(flagged >= 0, "这一局没有雷？")
    b.cycleFlag(flagged / b.w, flagged % b.w)
    if b.cells[flagged].flag == b.cells[flagged].mineKind + 1 {
        b.cycleFlag(flagged / b.w, flagged % b.w)
    }
    // 直接翻开所有非雷格 → 通关
    for i in 0..<b.cells.count {
        if b.isOver() { break }
        if b.cells[i].mineKind < 0 && !b.cells[i].isOpen {
            _ = b.reveal(i / b.w, i % b.w)
        }
    }
    check(b.isWon(), "翻开所有非雷格后应当通关")
    check(b.cells[flagged].endMark == MARK_RIGHT_FLAG, "通关时插在雷上的旗没有标成 MARK_RIGHT_FLAG")
    var shown = 0
    for cell in b.cells {
        if cell.mineKind < 0 || cell.flag != 0 { continue }
        check(cell.endMark == MARK_MINE, "通关时没插旗的雷没有亮出来")
        shown += 1
    }
    check(shown > 0, "这一局应该还有没插旗的雷")
    print("✓ 通关复盘：插旗的雷只看位置标绿勾，另外 \(shown) 颗没插旗的雷也亮出来了")
}

// ---------- 9. 与 HarmonyOS 版逐位对齐 ----------
//
// 下面这六个指纹是从 HarmonyOS 版的引擎（ArkTS，scripts/engine-check）跑出来的：
// 同一批固定种子、同一个首击格，把每格的雷型/显示值/邻雷数/翻开状态、四个计雷器
// 和胜负状态拼成一个字符串再做 FNV-1a。三个平台必须得到同一串值 —— 说明
// mulberry32、洗位置、求和、连片展开全都逐位一致，而不只是「看起来都对」。
do {
    func fnv(_ s: String) -> String {
        var h: UInt32 = 0x811c9dc5
        for b in s.utf8 {
            h ^= UInt32(b)
            h = h &* 0x01000193
        }
        return String(format: "%08x", h)
    }

    func fingerprint(_ w: Int, _ h: Int, _ mines: Int, _ seed: Int, _ sr: Int, _ sc: Int) -> String {
        let b = Board(w: w, h: h, mines: mines, seed: seed)
        b.startAt(sr, sc)
        var parts: [String] = []
        for c in b.cells {
            parts.append("\(c.mineKind + 1),\(c.clue),\(c.nbrMines),\(c.isOpen ? 1 : 0)")
        }
        for t in 0..<4 {
            parts.append("T\(b.typeTotal[t]),\(b.unmarked(t))")
        }
        parts.append("over\(b.isOver())won\(b.isWon())")
        return fnv(parts.joined(separator: ";"))
    }

    let cases: [(Int, Int, Int, Int, Int, Int, String)] = [
        (9, 9, 10, 1, 4, 4, "e89c77c9"),
        (16, 16, 40, 8, 8, 8, "d9ca35a9"),
        (30, 16, 99, 5, 8, 15, "04680c3c"),
        (9, 9, 10, 2024, 0, 0, "b5649eeb"),
        (16, 16, 40, 31337, 15, 15, "5c1eb7a8"),
        (30, 16, 99, 123456, 0, 29, "d7ac09af"),
    ]
    for (w, h, mines, seed, sr, sc, expected) in cases {
        let got = fingerprint(w, h, mines, seed, sr, sc)
        check(got == expected,
              "\(w)×\(h)/\(mines) seed=\(seed) @\(sr),\(sc) 的棋盘指纹是 \(got)，HarmonyOS 版是 \(expected)")
    }
    print("✓ 6 个固定种子的棋盘指纹与 HarmonyOS 版逐位一致：" + cases.map { $0.6 }.joined(separator: " "))
}

// ---------- 10. 三档难度 ----------
for d in kDifficulties {
    let b = Board(w: d.w, h: d.h, mines: d.mines, seed: 5)
    b.startAt(d.h / 2, d.w / 2)
    let n = b.cells.filter { $0.mineKind >= 0 }.count
    print("  \(d.label) \(d.w)×\(d.h) · \(d.mines) 雷 → 实际 \(n) 颗")
    check(n == d.mines, "\(d.label) 的雷数不对")
}

// 首击旗子保护、直接 reveal 开局、重复 startAt 与越界动作。
do {
    let b = Board(w: 9, h: 9, mines: 10, seed: 1)
    b.cycleFlag(4, 4)
    b.startAt(4, 4)
    check(!b.isStarted(), "带旗首击不能布雷")
    check(b.reveal(4, 4) == ACT_IGNORED && !b.isStarted(), "带旗首击不能开局")
    for _ in 0..<4 { b.cycleFlag(4, 4) }
    check(b.reveal(4, 4) == ACT_OK && b.isStarted(), "撤旗后 reveal 应正常开局")
    check(b.mineTotal() == 10 && b.cellAt(4, 4).isOpen, "直接 reveal 必须布置真实棋盘")
    let snapshot = b.cells.map { "\($0.mineKind),\($0.clue),\($0.isOpen)" }
    b.startAt(0, 0)
    check(snapshot == b.cells.map { "\($0.mineKind),\($0.clue),\($0.isOpen)" }, "重复 startAt 不能重布雷")
    for (r, c) in [(-1, 0), (0, -1), (9, 0), (0, 9)] {
        check(b.reveal(r, c) == ACT_IGNORED, "越界 reveal 必须忽略")
        check(b.tryExpand(r, c) == ACT_IGNORED, "越界展开必须忽略")
        check(!b.cycleFlag(r, c), "越界插旗必须忽略")
        b.startAt(r, c)
    }
    print("✓ 首击旗子保护、直接开局、重复开局与越界动作")
}

do {
    let b = Board(w: 3, h: 3, mines: 0, seed: 1)
    check(b.reveal(1, 1) == ACT_OK && b.isWon(), "首击开完所有安全格必须立即通关")
    check(b.cells.allSatisfy { $0.isOpen }, "零雷局应全部翻开")
    check(!b.cycleFlag(0, 0), "结束后不能继续插旗")
    print("✓ 首击即可通关并冻结棋盘")
}

do {
    let b = Board(w: 9, h: 9, mines: 10, seed: 1)
    b.startAt(4, 4)
    let c = b.cells.first { !$0.isOpen }!
    let updated = DispatchSemaphore(value: 0)
    withObservationTracking {
        _ = b.unmarked(0)
    } onChange: {
        updated.signal()
    }
    let before = b.unmarked(0)
    b.cycleFlag(c.row, c.col)
    check(updated.wait(timeout: .now()) == .success && b.unmarked(0) == before - 1, "SwiftUI 计雷器必须观察到插旗变化")
    print("✓ 计雷器 Observation 通知随插旗更新")
}

// ---------- 汇总 ----------


// 新模式与独立符号等价关系的回归。
do {
    var combos: [[Int]] = [], values: Set<Int> = []
    for p in 0...8 { for n in 0...(8-p) { for j in 0...(8-p-n) { for k in 0...(8-p-n-j) {
        combos.append([p,n,j,k]); values.insert((p-n)*(p-n)-(j-k)*(j-k))
    }}}}
    check(combos.count == 495 && values.sorted() == kHyperAchievable, "双曲39个显示值覆盖")
    check(formatClue(-1) == "i" && formatClue(-12) == "2√3i", "负显示值化简")
    var checks=0, negative=0, lightlike=0
    for d in kDifficulties { for seed in 1...120 {
        let b=Board(w:d.w,h:d.h,mines:d.mines,seed:seed,mode:.hyper)
        b.startAt(d.h/2,d.w/2)
        for i in b.cells.indices where !b.cells[i].isMine {
            let c=b.cells[i]; var a=0,j=0,count=0
            for n in neighborsOf(b,i) where b.cells[n].isMine {
                let t=kMineTypes[b.cells[n].mineKind];a+=t.re;j+=t.im;count+=1
            }
            check(c.clue == a*a-j*j && c.nbrMines == count && values.contains(c.clue), "双曲显示值错误")
            if c.clue<0 {negative+=1}
            if c.clue==0 && count>0 {lightlike+=1;check(!c.isBlank,"光锥零误当成空白")}
        }
        guard let center=b.cells.indices.first(where:{!b.cells[$0].isMine && b.cells[$0].nbrMines>0 && neighborsOf(b,$0).count==8}) else {fatalError("测试邻域缺失")}
        let ns=neighborsOf(b,center);var ta=0,tb=0,nt=0
        for n in ns where b.cells[n].isMine {let t=kMineTypes[b.cells[n].mineKind];ta+=t.re;tb+=t.im;nt+=1}
        for cc in combos {
            var flags:[Int]=[]
            for t in 0..<4 {flags+=Array(repeating:t+1,count:cc[t])}
            for i in 0..<8 {b.cells[ns[i]].flag=i<flags.count ? flags[i]:0}
            let fa=cc[0]-cc[1],fb=cc[2]-cc[3]
            let signs=[(ta,tb),(-ta,tb),(ta,-tb),(-ta,-tb)]
            let expected=flags.count==nt && signs.contains(where:{$0.0==fa && $0.1==fb})
            check(b.matchComboTruth(center)==expected,"双曲展开错误");checks+=1
        }
    }}
    check(negative>0 && lightlike>0,"未覆盖负值与非空白零")
    print("✓ 双曲360局、39显示值、\(checks)次展开判据、负值与非空白零")
    let cases:[(Int,Int,Int,Int,Int,Int,String)] = [(9,9,10,1,4,4,"1a6bf9f4"),(16,16,40,8,8,8,"4759fc78"),(30,16,99,5,8,15,"37233296"),(9,9,10,2024,0,0,"a0ef92af"),(16,16,40,31337,15,15,"7b20fba3"),(30,16,99,123456,0,29,"8de13a32")]
    for (w,h,m,s,r,c,expected) in cases {
        let b=Board(w:w,h:h,mines:m,seed:s,mode:.hyper);b.startAt(r,c)
        var parts=b.cells.map {"\($0.mineKind+1),\($0.clue),\($0.nbrMines),\($0.isOpen ? 1:0)"}
        for t in 0..<4 {parts.append("T\(b.typeTotal[t]),\(b.unmarked(t))")}
        parts.append("over\(b.isOver())won\(b.isWon())")
        var hash:UInt32=0x811c9dc5
        for byte in parts.joined(separator:";").utf8 {hash=(hash ^ UInt32(byte)) &* 0x01000193}
        check(String(format:"%08x",hash)==expected,"双曲固定种子指纹错误")
    }
    print("✓ 双曲6组参考指纹通过")
}


do {
    let domain = "ComplexSweeper-Regression-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set(19, forKey: "best_0")
    defaults.set(4, forKey: "wins_0")
    let store = StatsStore(slots: 6, defaults: defaults)
    check(store.entry(0).bestSeconds == 19 && store.entry(0).wins == 4, "原有圆复数纪录不能丢失")
    store.recordWin(3, seconds: 5)
    store.recordLoss(4)
    let reloaded = StatsStore(slots: 6, defaults: defaults)
    check(reloaded.entry(0).bestSeconds == 19 && reloaded.entry(0).wins == 4, "双曲结算不能覆盖圆复数纪录")
    check(reloaded.entry(3).bestSeconds == 5 && reloaded.entry(3).wins == 1 && reloaded.entry(4).losses == 1, "双曲战绩独立保存")
    print("✓ 旧纪录兼容、双曲战绩隔离与重新读取")
}

if failed > 0 {
    FileHandle.standardError.write("引擎自检失败：\(failed) 项\n".data(using: .utf8)!)
    exit(1)
}
print("✓ iOS / iPadOS / macOS 引擎自检全部通过")
