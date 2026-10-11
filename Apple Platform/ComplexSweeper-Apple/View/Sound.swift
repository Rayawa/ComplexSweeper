import Foundation
import AVFoundation
#if os(iOS)
import AVFAudio
#endif

/// bundle 里的六段音效，下标就是 play() 的参数
private let kSoundFiles: [String] = [
    "mine_1",   // 0 正实雷 +1
    "mine_2",   // 1 负实雷 -1
    "mine_3",   // 2 正虚雷 +i
    "mine_4",   // 3 负虚雷 -i
    "win",      // 4 通关
    "tick",     // 5 计时每秒一下
]

let SND_WIN: Int = 4
let SND_TICK: Int = 5

/// 音效池。
///
/// 六段音效是复扫雷作者青月晓自制的，随那个项目按 GPL-3.0 发布。
///
/// 音频不在关键路径上：设备没音频、加载出错，一律静默降级成无声，
/// 绝不能因为放不出声把游戏搞崩。所以外部不需要关心任何失败。
final class SoundBoard {
    private var players: [AVAudioPlayer?] = []

    init() {
        #if os(iOS)
        // .ambient：跟随静音开关，也不打断用户在听的音乐 —— 游戏音效本该如此
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
        #endif

        players = Array(repeating: nil, count: kSoundFiles.count)
        for (i, name) in kSoundFiles.enumerated() {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
            guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[i] = player
        }
    }

    func play(_ index: Int) {
        guard index >= 0 && index < players.count, let player = players[index] else { return }
        // 同一段音效重触发时从头播，不然连点几下会一点声音都没有
        if player.isPlaying {
            player.currentTime = 0
        }
        player.play()
    }

    /// 踩雷：按踩中的那一颗的雷型播，四种雷声音不同
    func playMine(_ kind: Int) {
        play(kind >= 0 && kind < 4 ? kind : 0)
    }
}
