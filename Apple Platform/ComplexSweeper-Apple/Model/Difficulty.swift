import Foundation

/// 一档难度。三档沿用复扫雷参考实现的标准配置。
///
/// 注意高级是 30 列 × 16 行（宽而扁），和经典扫雷专家局一致。
/// 手机上 30 列会超出一屏，棋盘横向可以滚动 —— 这是忠于参考实现的取舍，
/// 好处是格子和贴图都保持正常大小。
struct Difficulty: Identifiable, Hashable {
    let label: String
    /// 列数
    let w: Int
    /// 行数
    let h: Int
    let mines: Int

    var id: String { label }
}

let kDifficulties: [Difficulty] = [
    Difficulty(label: "初级", w: 9, h: 9, mines: 10),
    Difficulty(label: "中级", w: 16, h: 16, mines: 40),
    Difficulty(label: "高级", w: 30, h: 16, mines: 99),
]
