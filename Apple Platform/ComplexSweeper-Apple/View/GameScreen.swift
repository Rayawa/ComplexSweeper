import SwiftUI

/// 游戏主页。
///
/// 这个视图自己几乎不读任何会变的状态 —— 它只拿到一个稳定的 controller 引用，
/// 把版面搭出来。谁需要哪部分数据就让哪个子视图自己去读：计时走字只重算数码管，
/// 插旗只重算计雷器和那一格，480 格的网格纹丝不动。
struct GameScreen: View {
    @State private var game = GameController()
    @State private var showTutorial = false

    var body: some View {
        content
            .sheet(isPresented: $showTutorial) {
                TutorialSheet(onClose: { showTutorial = false })
            }
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        // macOS：难度放进窗口工具栏的分段选择器，不占棋盘地方
        mainColumn
            .frame(minWidth: 420, minHeight: 520)
            .toolbar {
                ToolbarItem { MacToolbar(game: game) }
                ToolbarItem(placement: .primaryAction) {
                    AboutButton { showTutorial = true }
                }
            }
        #else
        // iOS / iPadOS：难度是底部标签栏，和 HarmonyOS 版一致
        NavigationStack {
            mainColumn
                .navigationTitle("复扫雷")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        AboutButton { showTutorial = true }
                    }
                }
        }
        #endif
    }

    private var mainColumn: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HeaderPanel(game: game, pageHeight: geo.size.height)
                BoardPanel(game: game)
                StatusLine(game: game)
                #if os(iOS)
                DifficultyBar(game: game)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Classic.face)
        }
    }
}

/// 三档难度标签。切换难度只有真的换了难度才重开，来回切不会把手上的局作废。
struct DifficultyBar: View {
    let game: GameController

    var body: some View {
        HStack(spacing: 0) {
            ForEach(kDifficulties.indices, id: \.self) { i in
                Button {
                    game.selectDifficulty(i)
                } label: {
                    VStack(spacing: 2) {
                        PixelImage(name: Sprites.tab(i), width: 24, height: 24)
                        Text(kDifficulties[i].label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .foregroundStyle(game.difficultyIndex == i ? Color.accentColor : Classic.dark)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.bottom, 2)
        .background(Classic.face)
        .overlay(alignment: .top) {
            Rectangle().fill(Classic.shadow).frame(height: 1)
        }
    }
}

/// macOS 工具栏上的难度选择器
struct MacToolbar: View {
    let game: GameController

    var body: some View {
        Picker("难度", selection: Binding(
            get: { game.difficultyIndex },
            set: { game.selectDifficulty($0) }
        )) {
            ForEach(kDifficulties.indices, id: \.self) { i in
                Text(kDifficulties[i].label).tag(i)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 220)
    }
}

/// 标题栏上的「关于」按钮，三个难度页都能点开
struct AboutButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("关于", systemImage: "info.circle")
        }
        .accessibilityLabel("关于")
    }
}
