import SwiftUI

/// 复扫雷 · 扫雷，但雷是复数。
///
/// 单一 multiplatform target：iOS、iPadOS、macOS 共用同一套 SwiftUI 代码与素材，
/// 只有指针/触摸这一层用 `#if os(...)` 分叉 —— 触屏是「轻点标记、长按翻开」，
/// 桌面是「左键翻开、右键标记」。
@main
struct ComplexSweeperApp: App {
    var body: some Scene {
        WindowGroup("复扫雷") {
            GameScreen()
        }
        #if os(macOS)
        .defaultSize(width: 760, height: 660)
        .windowResizability(.contentMinSize)
        #endif
    }
}
