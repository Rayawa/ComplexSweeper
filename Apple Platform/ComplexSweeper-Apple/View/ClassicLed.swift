import SwiftUI

/// 数码管里的特殊格子
private let CELL_BLANK: Int = 12
private let CELL_MINUS: Int = 10
private let CELL_UNIT_I: Int = 11

/// 一排数码管。
///
/// 复扫雷的计雷器是「这一类雷还剩几颗没标」，虚雷那一档最后一格是 i 单位而不是数字，
/// 所以这里要能按需留出单位格。数字一律右对齐、前导零不亮。
struct LedReadout: View {
    var value: Int = 0
    /// 一共几格
    var slots: Int = 4
    /// 最后一格是 i 单位（正虚雷、负虚雷用）
    var imagUnit: Bool = false
    var hyperUnit: Bool = false
    /// 单格宽度；高度按贴图比例 23:13 算
    var cellWidth: CGFloat = 13
    /// 还没开局时不显示任何数字 —— 那时各类雷的颗数还没抽出来
    var blankAll: Bool = false

    private var cellHeight: CGFloat { cellWidth * 23 / 13 }

    /// 算出每一格该显示什么：0..9 数字、10 负号、11 i 单位、12 空格
    private func codes() -> [Int] {
        var out = Array(repeating: CELL_BLANK, count: slots)
        if blankAll { return out }
        let digitSlots = imagUnit ? slots - 1 : slots
        let negative = value < 0
        var rest = abs(value)

        var pos = digitSlots - 1
        while pos >= 0 {
            out[pos] = rest % 10
            rest /= 10
            if rest == 0 { break }
            pos -= 1
        }
        // 负号紧挨在最高位数字左边；位数占满了就只好不画负号
        if negative && pos - 1 >= 0 {
            out[pos - 1] = CELL_MINUS
        }
        if imagUnit && slots > 0 {
            out[slots - 1] = hyperUnit ? 13 : CELL_UNIT_I
        }
        return out
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(codes().enumerated()), id: \.offset) { _, code in
                PixelImage(name: Sprites.led(code), width: cellWidth, height: cellHeight)
            }
        }
        .padding(2)
        .background(Classic.ledBackground)
    }
}
