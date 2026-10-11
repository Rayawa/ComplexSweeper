import SwiftUI

/// 「关于」底部展示的版本号，与工程配置的 MARKETING_VERSION 保持一致
let kAppVersion: String = "1.0"

/// 「关于」弹层的内容。
///
/// 上半是基础规则：数字怎么来的、四种雷、空白和 0 的区别、怎么操作 ——
/// 展开的判定细节和 24 个可达值都没有展开写，上手之后自然碰到，
/// 这里再列一遍只会把基础规则淹掉。下半是版本、开发者与版权。
struct TutorialContent: View {
    /// ForEach 要遍历的四种雷下标
    private let typeIndexes: [Int] = [0, 1, 2, 3]

    // ---------------- 顶部：图标 + 中英文名 ----------------

    private var appHeader: some View {
        HStack(spacing: 14) {
            PixelImage(name: Sprites.icon, width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text("复扫雷")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Classic.dark)
                Text("ComplexSweeper")
                    .font(.system(size: 13))
                    .foregroundStyle(Classic.shadow)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Classic.face)
        .classicBevel(raised: true)
    }

    // ---------------- 排版小件 ----------------

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Classic.dark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    private func body(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .lineSpacing(4)
            .foregroundStyle(Classic.dark)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }

    /// 四种雷：旗帜贴图 + 名字
    private var typeRow: some View {
        HStack(spacing: 20) {
            ForEach(typeIndexes, id: \.self) { t in
                VStack(spacing: 4) {
                    PixelImage(name: Sprites.flag(t + 1), width: 30, height: 30)
                    Text(kTypeLabels[t])
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Classic.dark)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Classic.shadow)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.bottom, 6)
    }

    // ---------------- 组装 ----------------

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                appHeader

                sectionTitle("怎么玩")
                body("格子上的数字，是周围所有雷之和的模长。翻开所有非雷格就赢。")

                sectionTitle("四种雷")
                body("它们当复数相加，和再取模长就是格子上的数。比如周围有一颗 +1 和一颗 −i，"
                     + "和是 1−i，显示 √2。")
                typeRow

                sectionTitle("空白和 0 不是一回事")
                body("空白格：周围一颗雷都没有。")
                body("显示 0：周围有雷，但正负两两抵消了。")

                sectionTitle("操作")
                #if os(macOS)
                body("左键已翻开的数字格：周围旗子插对时，一次掀开周围没插旗的格子。")
                body("左键未翻开的格子：翻开。插了旗的格子翻不开，得先用右键把旗循环回空。")
                body("右键未翻开的格子：循环标记 空 → +1 → −1 → +i → −i → 空。")
                #else
                body("单击未翻开的格子：循环标记 空 → +1 → −1 → +i → −i → 空。")
                body("长按未翻开的格子：翻开。插了旗的格子翻不开，得先把旗循环回空。")
                body("单击已翻开的数字格：周围旗子插对时，一次掀开周围没插旗的格子。")
                #endif

                Divider()
                    .overlay(Classic.shadow)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                footer("版本 \(kAppVersion)")
                Link("原作 青月晓 · Complexweeper ↗",
                     destination: URL(string: "https://github.com/Yueqing-Chen/complexweeper-A-minesweeper-game")!)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.blue)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)
                    .accessibilityIdentifier("original-repository")
                    .accessibilityLabel("原作 青月晓，打开原仓库 GitHub")
                footer("iOS / iPadOS / macOS 移植 Ray Chen (Rayawa)")
                footer("Copyright © 2026 Ray Chen (Rayawa)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 32)
        }
        .background(Classic.face)
    }
}

/// 「关于」弹层。
///
/// 标题栏自己画：系统那套只收文字、给不了颜色，标题和关闭按钮都会是系统灰，
/// 压在银灰面板上不好看。
struct TutorialSheet: View {
    var onClose: () -> Void

    #if os(macOS)
    private let minSize = CGSize(width: 460, height: 560)
    #else
    private let minSize = CGSize(width: 0, height: 0)
    #endif

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("关于")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Classic.dark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Classic.dark)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            TutorialContent()
        }
        .frame(minWidth: minSize.width, minHeight: minSize.height)
        .background(Classic.face)
        .presentationDragIndicator(.visible)
    }
}
