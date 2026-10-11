import SwiftUI

/// 棋盘：经典凹陷面板包住网格。
///
/// 网格用 VStack 套 HStack 逐格摆，不用 LazyVGrid —— 列数是固定的，
/// 而 LazyVGrid 的列宽算法会把除不尽的余数摊到列距上，像素贴图之间就会
/// 出现半像素的缝。固定列数的 HStack 没有这个自由度，一定对齐。
///
/// **装得下就不套 ScrollView**。滚动容器会在格子上面多压一层手势竞争者，
/// 轻点要先被它过一遍，手感会发滞；初级、中级在手机上都装得下，没必要付这个成本。
/// 只有高级 30 列（或者矮窗里放不下整块棋盘）才真的需要滚动。
struct BoardPanel: View {
    let game: GameController

    var body: some View {
        GeometryReader { geo in
            // 列数、行数、格子数组必须**来自同一份棋盘**，所以在这里一次性取出来，
            // 当作快照传给下面的网格。
            //
            // 别在网格的闭包里现读 game.board：ForEach 的内容闭包是在视图更新过程中
            // 才求值的，那时 game.board 可能已经换成下一局了，而 cols 还是上一局的 ——
            // 30 列切回 9 列那一下就变成 r*30+c 去索引一个 81 格的数组，直接越界崩。
            let board = game.board
            let cols = board.w
            let rows = board.h
            let cells = board.cells
            let inner = CGSize(
                width: max(geo.size.width - ClassicLayout.panelBox, 0),
                height: max(geo.size.height - ClassicLayout.panelBox, 0)
            )
            let edge = ClassicLayout.edge(cols: cols, rows: rows, inner: inner)
            let gridWidth = edge * CGFloat(cols)
            let gridHeight = edge * CGFloat(rows)
            // 半像素的余量：浮点除下来差一点点不算「放不下」
            let fits = gridWidth <= inner.width + 0.5 && gridHeight <= inner.height + 0.5

            let grid = BoardGrid(game: game, cells: cells, cols: cols, rows: rows, edge: edge)
                // 开新局时整块网格重建，别让 SwiftUI 把上一局的格子复用过来
                .id(game.gameId)

            Group {
                if fits {
                    // 装得下：直接撑满面板、把网格居中，一层视图都不多
                    grid.frame(width: inner.width, height: inner.height, alignment: .center)
                } else {
                    // 装不下：网格容器撑到至少可视区大小，居中交给对齐，装不下的部分滚动
                    ScrollView([.horizontal, .vertical]) {
                        grid.frame(minWidth: inner.width, minHeight: inner.height, alignment: .center)
                    }
                }
            }
            .frame(width: inner.width, height: inner.height)
            .background(Classic.face)
            .classicBevel(raised: false)
            // 给 UI 测试一个能定位到棋盘面板的抓手（也顺带把 480 个格子收成一块，
            // VoiceOver 不会在棋盘上刷出几百个无标签元素）
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("board")
            .id(game.gameId)
        }
    }
}

/// 一块网格。
///
/// `cells` 与 `cols` / `rows` 是同一次取出来的快照，三者一定自洽，索引不可能越界。
/// 这里刻意不再碰 `game.board`。
private struct BoardGrid: View {
    let game: GameController
    let cells: [Cell]
    let cols: Int
    let rows: Int
    let edge: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<cols, id: \.self) { c in
                        CellView(game: game, cell: cells[r * cols + c], edge: edge)
                    }
                }
            }
        }
    }
}
