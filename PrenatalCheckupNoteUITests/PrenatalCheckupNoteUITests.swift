//
//  PrenatalCheckupNoteUITests.swift
//  PrenatalCheckupNoteUITests
//
//  Created by 関貴斗 on 2026/10/23.
//

import XCTest

/// アプリが起動して前面に表示されることだけを確かめる、最小のUIテスト。
/// 画面ごとのUIテストは、段階1以降で画面を作るときに追加する。
final class PrenatalCheckupNoteUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
