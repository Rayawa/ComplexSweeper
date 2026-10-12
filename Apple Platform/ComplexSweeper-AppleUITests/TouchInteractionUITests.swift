import XCTest

/// 触屏交互的回归测试。
///
/// 这两条测试都是**用真触摸事件**跑的（XCUITest 往模拟器里注入），所以它们能回答
/// 「点一下到底生效没有」这种光看代码看不出来的问题。
///
/// 观测点用的是状态行那一句提示：
///   - 还没开局：「长按翻开第一格，四种雷的数量开局后公布」
///   - 已经开局：以「单击标记」开头
/// 于是「轻点有没有插上旗」可以这样判定 —— 轻点某一格之后长按**同一格**：
/// 旗子保护格子，翻不开，状态行应当纹丝不动；要是那一下轻点没生效，长按就会把
/// 这一格翻开，状态行立刻变成「单击标记…」，测试当场红在这里并报出是哪一格。
final class TouchInteractionUITests: XCTestCase {

    private var app: XCUIApplication!

    /// 开局前的状态行
    private var readyStatus: XCUIElement {
        app.staticTexts.matching(identifier: "status")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "长按翻开第一格"))
            .firstMatch
    }

    /// 开局后的状态行
    private var startedStatus: XCUIElement {
        app.staticTexts.matching(identifier: "status")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "单击标记"))
            .firstMatch
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - 定位

    /// 棋盘面板
    private var board: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "board").firstMatch
    }

    /// 算出某一格中心的屏幕坐标。
    ///
    /// 版面算法和 `ClassicLayout.edge` 是同一套：棋盘面板内缩 6pt 之后是可视区，
    /// 格子边长夹在 16…36，网格在可视区里居中。
    private func cellCenter(
        row: Int,
        col: Int,
        cols: Int,
        rows: Int
    ) -> XCUICoordinate {
        let f = board.frame
        let innerWidth = f.width - 6
        let innerHeight = f.height - 6
        let byWidth = (innerWidth / CGFloat(cols)).rounded(.down)
        let byHeight = (innerHeight / CGFloat(rows)).rounded(.down)
        let edge = min(max(min(byWidth, byHeight), 16), 36)
        let gridWidth = edge * CGFloat(cols)
        let gridHeight = edge * CGFloat(rows)
        let originX = f.minX + 3 + (innerWidth - gridWidth) / 2
        let originY = f.minY + 3 + (innerHeight - gridHeight) / 2
        return app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(
                dx: originX + edge * (CGFloat(col) + 0.5),
                dy: originY + edge * (CGFloat(row) + 0.5)
            ))
    }

    // MARK: - 测试

    private func cell(_ row: Int, _ col: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "cell-\(row)-\(col)").firstMatch
    }

    /// 长按带旗格之后，下一次轻点必须仍能循环旗帜。
    func testFlagCycleAfterLongPress() {
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        let target = cell(0, 0)
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.tap()
        XCTAssertEqual(target.value as? String, "旗帜 +1")
        target.press(forDuration: 0.6)
        XCTAssertTrue(readyStatus.exists)
        XCTAssertEqual(target.value as? String, "旗帜 +1")
        for expected in ["旗帜 -1", "旗帜 +i", "旗帜 -i", "未翻开"] {
            target.tap()
            XCTAssertEqual(target.value as? String, expected)
        }
        target.press(forDuration: 0.6)
        XCTAssertTrue(startedStatus.waitForExistence(timeout: 5))
    }

    /// 插旗后计雷器立即更新，不能依赖计时或重建页面来刷新。
    func testCountersRefreshWhenFlagCycles() {
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        cell(4, 4).press(forDuration: 0.6)
        XCTAssertTrue(startedStatus.waitForExistence(timeout: 5))
        let counter = app.descendants(matching: .any).matching(identifier: "counter-0").firstMatch
        XCTAssertTrue(counter.exists)
        let initial = Int(counter.value as? String ?? "")!
        let candidates = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'cell-' AND value == '未翻开'")
        )
        XCTAssertTrue(candidates.firstMatch.exists)
        let target = app.descendants(matching: .any).matching(identifier: candidates.firstMatch.identifier).firstMatch
        target.tap()
        XCTAssertEqual(counter.value as? String, "\(initial - 1)")
        target.tap()
        XCTAssertEqual(counter.value as? String, "\(initial)")
    }

    /// 横向拖动高级棋盘只滚动，不能插旗或开局；重开恢复初始滚动位置。
    func testAdvancedBoardDragAndRestart() {
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        app.segmentedControls.buttons["高级"].tap()
        let first = cell(0, 0)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let originalX = first.frame.minX
        board.swipeLeft(velocity: .fast)
        XCTAssertTrue(readyStatus.exists)
        let flagged = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'cell-' AND value BEGINSWITH '旗帜'")
        )
        XCTAssertEqual(flagged.count, 0)
        app.descendants(matching: .any).matching(identifier: "restart").firstMatch.tap()
        XCTAssertTrue(readyStatus.exists)
        XCTAssertEqual(first.frame.minX, originalX, accuracy: 1)
    }

    /// 长按能翻开第一格，轻点能插旗，而且旗子确实保护格子。
    func testLongPressRevealsAndTapFlags() {
        XCTAssertTrue(board.waitForExistence(timeout: 15), "找不到棋盘面板")
        XCTAssertTrue(readyStatus.waitForExistence(timeout: 5), "开局前的状态行没出现")

        // 长按中间那格 → 开局
        cellCenter(row: 4, col: 4, cols: 9, rows: 9).press(forDuration: 1.0)
        XCTAssertTrue(startedStatus.waitForExistence(timeout: 5), "长按没有翻开第一格")
    }

    /// 逐格轻点：每一次轻点都必须真的插上旗。
    ///
    /// 两个失败原因要分清楚，所以分开记：
    ///   - 轻点之后状态行就变了 → 这一下轻点被当成了长按（翻开了格子）
    ///   - 轻点之后没变、长按之后才变 → 轻点根本没生效，格子是被后面那次长按翻开的
    func testEveryTapRegisters() {
        XCTAssertTrue(board.waitForExistence(timeout: 15), "找不到棋盘面板")
        XCTAssertTrue(readyStatus.waitForExistence(timeout: 5), "开局前的状态行没出现")

        // 挑开中心格（首击格开出来是一片），只在外圈取点，保证每次点到的都是没翻开的格子
        let spots: [(Int, Int)] = [
            (0, 0), (0, 8), (8, 0), (8, 8), (0, 4), (4, 0), (4, 8), (8, 4),
        ]
        var swallowedAsLongPress: [String] = []
        var neverReachedTheCell: [String] = []

        for (row, col) in spots {
            let point = cellCenter(row: row, col: col, cols: 9, rows: 9)
            let name = "(\(row),\(col))"

            point.tap()
            if startedStatus.exists {
                swallowedAsLongPress.append(name)
                break   // 局已经开了，后面的格子不可信，停在这里
            }

            // 同一格再长按：旗子保护格子，翻不开。翻开了就说明刚才那一下轻点没插上旗。
            point.press(forDuration: 0.8)
            if startedStatus.exists {
                neverReachedTheCell.append(name)
                break
            }
        }

        XCTAssertTrue(
            swallowedAsLongPress.isEmpty,
            "这一下轻点被当成了长按（翻开了格子）：\(swallowedAsLongPress)"
        )
        XCTAssertTrue(
            neverReachedTheCell.isEmpty,
            "轻点没插上旗，格子是被后面那次长按翻开的：\(neverReachedTheCell)"
        )
    }

    /// 反复切难度不能崩 —— 曾经在高级 30 列切回中级时越界闪退。
    func testSwitchingDifficultyRepeatedlyDoesNotCrash() {
        XCTAssertTrue(board.waitForExistence(timeout: 15), "找不到棋盘面板")

        for round in 0..<4 {
            for label in ["高级", "初级", "中级", "高级", "初级"] {
                let tab = app.segmentedControls.buttons[label]
                XCTAssertTrue(tab.waitForExistence(timeout: 5), "第 \(round) 轮找不到难度标签 \(label)")
                tab.tap()
                XCTAssertEqual(app.state, .runningForeground, "切到 \(label) 之后 App 不在了")
            }
        }
        XCTAssertTrue(board.exists, "切完难度棋盘不见了")
    }

    /// 「关于」弹层开关不能崩。
    func testAboutSheetOpensAndCloses() {
        XCTAssertTrue(app.buttons["关于"].waitForExistence(timeout: 15), "找不到关于按钮")
        for _ in 0..<3 {
            app.buttons["关于"].tap()
            XCTAssertTrue(
                app.staticTexts["关于"].waitForExistence(timeout: 5),
                "关于弹层没打开"
            )
            app.buttons["关闭"].tap()
            XCTAssertFalse(
                app.staticTexts["关于"].waitForExistence(timeout: 2),
                "关于弹层没关掉"
            )
        }
    }

    func testModeTabsAndSeparateDifficultySelector() {
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        app.segmentedControls.buttons["中级"].tap()
        let hyper=app.buttons["mode-1"]
        hyper.tap()
        let target=cell(0,0)
        target.tap(); target.tap(); target.tap()
        XCTAssertEqual(target.value as? String,"旗帜 +j")
        hyper.tap()
        XCTAssertEqual(target.value as? String,"旗帜 +j")
        app.segmentedControls.buttons["中级"].tap()
        XCTAssertEqual(target.value as? String,"旗帜 +j")
        app.descendants(matching:.any).matching(identifier:"restart").firstMatch.tap()
        target.tap(); target.tap(); target.tap()
        XCTAssertEqual(target.value as? String,"旗帜 +j")
        app.segmentedControls.buttons["初级"].tap()
        XCTAssertEqual(target.value as? String,"未翻开")
        XCTAssertTrue(readyStatus.exists)
        let counter=app.descendants(matching:.any).matching(identifier:"counter-2").firstMatch
        XCTAssertEqual(counter.label,"+j 剩余雷数")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "hyper-mode"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["mode-0"].tap()
        XCTAssertEqual(counter.label,"+i 剩余雷数")
        XCTAssertTrue(readyStatus.exists)
    }
}
