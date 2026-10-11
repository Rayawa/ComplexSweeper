import Foundation
import Observation

/// 一档难度的历史战绩
struct DifficultyStats: Equatable {
    var wins: Int = 0
    var losses: Int = 0
    /// 最快通关秒数，0 表示还没通关过
    var bestSeconds: Int = 0
}

/// 战绩存档。
///
/// 用 UserDefaults：iOS / iPadOS / macOS 上都有，而且不需要 await。
/// 存档坏了顶多丢记录，绝不能连累游戏本身 —— 所以读一律给默认值，写不检查结果。
@Observable
final class StatsStore {
    private let defaults: UserDefaults
    private(set) var entries: [DifficultyStats]

    init(slots: Int, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded: [DifficultyStats] = []
        loaded.reserveCapacity(slots)
        for i in 0..<slots {
            loaded.append(DifficultyStats(
                wins: defaults.integer(forKey: "wins_\(i)"),
                losses: defaults.integer(forKey: "losses_\(i)"),
                bestSeconds: defaults.integer(forKey: "best_\(i)")
            ))
        }
        self.entries = loaded
    }

    func entry(_ index: Int) -> DifficultyStats {
        (index >= 0 && index < entries.count) ? entries[index] : DifficultyStats()
    }

    func recordWin(_ index: Int, seconds: Int) {
        guard index >= 0 && index < entries.count else { return }
        var e = entries[index]
        e.wins += 1
        if e.bestSeconds == 0 || seconds < e.bestSeconds {
            e.bestSeconds = seconds
        }
        entries[index] = e
        persist(index)
    }

    func recordLoss(_ index: Int) {
        guard index >= 0 && index < entries.count else { return }
        entries[index].losses += 1
        persist(index)
    }

    private func persist(_ index: Int) {
        let e = entries[index]
        defaults.set(e.wins, forKey: "wins_\(index)")
        defaults.set(e.losses, forKey: "losses_\(index)")
        defaults.set(e.bestSeconds, forKey: "best_\(index)")
    }
}
