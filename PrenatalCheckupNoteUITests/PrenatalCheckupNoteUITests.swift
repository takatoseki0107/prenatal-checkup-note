//
//  PrenatalCheckupNoteUITests.swift
//  PrenatalCheckupNoteUITests
//
//  Created by 関貴斗 on 2026/10/23.
//

import XCTest

/// アプリが起動して前面に表示されることだけを確かめる、最小の画面のテスト。
///
/// 本当のデータに触れないよう、画面のテスト用の保存場所を空にして起動する。
final class PrenatalCheckupNoteUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
