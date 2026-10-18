import XCTest

/// 触屏交互回归：用真实触摸事件验证轻点循环标记、长按清旗翻开与布局。

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

    /// 两种模式的每种标记都能长按清除并安全首击，其他标记不被连片清除。
    func testLongPressClearsEveryFlagAndStartsGame() {
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        for mode in 0...1 {
            app.buttons["mode-\(mode)"].tap()
            for flag in 1...4 {
                app.descendants(matching: .any).matching(identifier: "restart").firstMatch.tap()
                let target = cell(0, 0)
                for _ in 0..<flag { target.tap() }
                XCTAssertTrue((target.value as? String ?? "").hasPrefix("旗帜"))
                cell(0, 1).tap()
                target.press(forDuration: 0.6)
                XCTAssertTrue(startedStatus.waitForExistence(timeout: 5))
                XCTAssertEqual(target.value as? String, "空白")
                XCTAssertEqual(cell(0, 1).value as? String, "旗帜 +1")
            }
        }
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
        let negative = app.descendants(matching: .any).matching(identifier: "counter-1").firstMatch
        let negativeBefore = Int(negative.value as? String ?? "")!
        target.press(forDuration: 0.6)
        XCTAssertFalse((target.value as? String ?? "").hasPrefix("旗帜"))
        XCTAssertEqual(negative.value as? String, "\(negativeBefore - 1)")
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

    /// 长按能翻开第一格。
    func testLongPressRevealsAndTapFlags() {
        XCTAssertTrue(board.waitForExistence(timeout: 15), "找不到棋盘面板")
        XCTAssertTrue(readyStatus.waitForExistence(timeout: 5), "开局前的状态行没出现")

        // 长按中间那格 → 开局
        cellCenter(row: 4, col: 4, cols: 9, rows: 9).press(forDuration: 1.0)
        XCTAssertTrue(startedStatus.waitForExistence(timeout: 5), "长按没有翻开第一格")
    }

    /// 逐格轻点都应插旗，不能误触成长按；完整循环应回到未翻开。
    func testEveryTapRegisters() {
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        let spots = [(0, 0), (0, 8), (8, 0), (8, 8), (0, 4), (4, 0), (4, 8), (8, 4)]
        for (row, col) in spots {
            let target = cell(row, col)
            target.tap()
            XCTAssertTrue(readyStatus.exists)
            XCTAssertEqual(target.value as? String, "旗帜 +1")
            for expected in ["旗帜 -1", "旗帜 +i", "旗帜 -i", "未翻开"] {
                target.tap()
                XCTAssertEqual(target.value as? String, expected)
            }
        }
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
    func testAppearanceKeepsBoardAndPersistsAfterRelaunch() {
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        let appearance = app.segmentedControls["appearance"]
        XCTAssertTrue(appearance.exists)
        let initial = appearance.buttons["彩色"].isSelected ? "彩色" : "黑白"
        let selected = initial == "彩色" ? "黑白" : "彩色"
        defer { appearance.buttons[initial].tap() }
        cell(0, 0).tap()
        cell(4, 4).press(forDuration: 0.6)
        XCTAssertTrue(startedStatus.waitForExistence(timeout: 5))
        let cells = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'cell-'")
        )
        let before = cells.allElementsBoundByIndex.map { "\($0.identifier):\($0.value as? String ?? "")" }
        appearance.buttons[selected].tap()
        XCTAssertTrue(appearance.buttons[selected].isSelected)
        appearance.buttons[selected].tap()
        XCTAssertTrue(appearance.buttons[selected].isSelected)
        XCTAssertEqual(cell(0, 0).value as? String, "旗帜 +1")
        XCTAssertTrue(startedStatus.exists)
        XCTAssertEqual(cells.allElementsBoundByIndex.map { "\($0.identifier):\($0.value as? String ?? "")" }, before)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "appearance-switched"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        XCTAssertTrue(appearance.waitForExistence(timeout: 15))
        XCTAssertTrue(appearance.buttons[selected].isSelected)
        // 外观同样适用于双曲模式；切换仍保留 j 旗帜。
        app.buttons["mode-1"].tap()
        cell(0, 0).tap(); cell(0, 0).tap(); cell(0, 0).tap()
        appearance.buttons[initial].tap()
        XCTAssertEqual(cell(0, 0).value as? String, "旗帜 +j")
    }

    func testAppearanceAndDifficultyFitBothOrientations() {
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        defer { XCUIDevice.shared.orientation = .portrait }
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let appearance = app.segmentedControls["appearance"]
            let difficulty = app.segmentedControls["difficulty"]
            XCTAssertTrue(appearance.waitForExistence(timeout: 5))
            XCTAssertTrue(difficulty.exists)
            if orientation == .landscapeLeft {
                XCTAssertGreaterThan(app.frame.width, app.frame.height)
            } else {
                XCTAssertGreaterThan(app.frame.height, app.frame.width)
            }
            XCTAssertTrue(appearance.buttons["彩色"].isHittable)
            XCTAssertTrue(appearance.buttons["黑白"].isHittable)
            XCTAssertTrue(difficulty.buttons["高级"].isHittable)
            XCTAssertGreaterThanOrEqual(appearance.frame.minX, difficulty.frame.maxX - 1)
            XCTAssertLessThanOrEqual(appearance.frame.maxX, app.frame.maxX + 1)
            XCTAssertEqual(appearance.frame.midY, difficulty.frame.midY, accuracy: 4)
            let selected = appearance.buttons["彩色"].isSelected ? "彩色" : "黑白"
            let target = cell(0, 0)
            let previous = target.value as? String
            appearance.buttons[selected].tap()
            XCTAssertEqual(target.value as? String, previous)
            let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            capture.name = "appearance-layout-\(orientation.rawValue)"
            capture.lifetime = .keepAlways
            add(capture)
        }
    }

}
