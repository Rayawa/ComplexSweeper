import SwiftUI
#if os(macOS)
import AppKit
#endif

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
            .background(MacWindowTitle().frame(width: 0, height: 0))
            .toolbar {
                if #available(macOS 26.0, *) {
                    ToolbarItem(placement: .principal) { AppTitle() }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .principal) { AppTitle() }
                }
                ToolbarItem { MacToolbar(game: game) }
                ToolbarItem(placement: .primaryAction) {
                    AboutButton { showTutorial = true }
                }
            }
        #else
        // iOS / iPadOS：底部切模式，棋盘上方分段选择难度
        NavigationStack {
            mainColumn
                .navigationTitle("复扫雷")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) { AppTitle() }
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
                #if os(iOS)
                DifficultyBar(game: game)
                #endif
                HeaderPanel(game: game, pageHeight: geo.size.height)
                BoardPanel(game: game)
                StatusLine(game: game)
                ModeBar(game: game)
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
        Picker("难度", selection: Binding(
            get: { game.difficultyIndex }, set: { game.selectDifficulty($0) }
        )) {
            ForEach(kDifficulties.indices, id: \.self) { i in
                Text(kDifficulties[i].label).tag(i)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .accessibilityIdentifier("difficulty")
    }
}

struct ModeBar: View {
    let game: GameController
    var body: some View {
        HStack(spacing: 0) {
            ForEach(GameMode.allCases, id: \.rawValue) { mode in
                Button { game.selectMode(mode) } label: {
                    VStack(spacing: 2) {
                        PixelImage(name: Sprites.flag(3, mode: mode), width: 24, height: 24)
                        Text(mode.label).font(.system(size: 12, weight: game.mode == mode ? .bold : .regular))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .foregroundStyle(game.mode == mode ? Color.accentColor : Classic.dark)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mode-\(mode.rawValue)")
                .accessibilityAddTraits(game.mode == mode ? [.isSelected] : [])
            }
        }
        .background(Classic.face)
        .overlay(alignment: .top) { Rectangle().fill(Classic.shadow).frame(height: 1) }
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
        .foregroundStyle(Color.black)
        .accessibilityLabel("关于")
    }
}

/// 显式使用黑色，避免系统导航标题在深色环境中变成白色。
private struct AppTitle: View {
    var body: some View {
        Text("复扫雷")
            .font(.headline)
            .foregroundStyle(Color.black)
            .accessibilityIdentifier("app-title")
    }
}

#if os(macOS)
/// 保留窗口名称供系统识别，屏幕上由黑色的 SwiftUI 标题负责显示。
private struct MacWindowTitle: NSViewRepresentable {
    func makeNSView(context: Context) -> TitleView { TitleView() }
    func updateNSView(_ view: TitleView, context: Context) {
        view.window?.titleVisibility = .hidden
    }
    final class TitleView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.titleVisibility = .hidden
        }
    }
}
#endif
