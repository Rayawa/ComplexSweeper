import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 触感强度。三档和复扫雷的音效一一对应，不做更细的区分。
private enum HapticStrength {
    case light
    case medium
    case heavy
}

/// 轻振 / 触感反馈。
///
/// 长按开格如果没有任何触感反馈，手指会不确定自己到底按够时间没有 ——
/// 这个游戏里「按够没有」直接决定是标记还是开格，所以反馈很重要。
///
/// 触感不在关键路径上：设备不支持、用户关掉、调用失败，一律静默吞掉。
/// macOS 上没有触控板力反馈的设备同样什么都不做。
private func feedback(_ strength: HapticStrength) {
    #if os(iOS)
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    switch strength {
    case .light: style = .light
    case .medium: style = .medium
    case .heavy: style = .heavy
    }
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
    #elseif os(macOS)
    let pattern: NSHapticFeedbackManager.FeedbackPattern
    switch strength {
    case .light: pattern = .alignment
    case .medium: pattern = .generic
    case .heavy: pattern = .levelChange
    }
    NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    #endif
}

/// 单击：标记切换
func feedbackTick() {
    feedback(.light)
}

/// 长按：开格
func feedbackReveal() {
    feedback(.medium)
}

/// 踩雷或通关
func feedbackOutcome() {
    feedback(.heavy)
}
