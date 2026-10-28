import XCTest

/// 中心の流れと、起動し直しても入力が残ることを、実際の画面を操作して確かめる（要件定義 v0.4 の 8 章「画面のテスト」）。
///
/// アプリには「画面のテスト用の保存場所を使う」合図を渡し、本当のデータには触れない。
/// 文字は日本語なので、ボタンや文は画面に出る言葉で探す。入力欄だけは名前（accessibilityIdentifier）で探す。
final class CoreFlowUITests: XCTestCase {
    /// CI のシミュレーターは遅いことがあるので、画面が出るまで長めに待つ。
    private let timeout: TimeInterval = 30

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 質問を追加 → 丸 → 健診後メモを保存 → 健診の記録で見る → 元に戻す。
    @MainActor
    func testAddAskSaveLookBackAndUndo() throws {
        let app = launch(resettingData: true)
        skipOnboarding(app)

        // 質問を追加する。
        addQuestion("むくみ", in: app)
        XCTAssertTrue(element(labelContaining: "むくみ", in: app).waitForExistence(timeout: timeout))

        // 丸を付ける（聞いた）。
        app.buttons["聞く前"].firstMatch.tap()
        XCTAssertTrue(app.buttons["聞いた"].firstMatch.waitForExistence(timeout: timeout))

        // 健診後メモを書いて保存する。
        app.buttons["健診後メモを書く"].tap()
        let body = field("memoBodyField", in: app)
        XCTAssertTrue(body.waitForExistence(timeout: timeout))
        body.tap()
        body.typeText("様子見でよい")
        // 入力中は保存の帯が隠れるので、キーボードの上の「完了」で閉じてから保存する（段階 F）。
        app.buttons["完了"].firstMatch.tap()
        let saveButton = app.buttons["メモと質問 1 件を保存"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: timeout))
        saveButton.tap()

        // 丸を付けた質問はメモに移り、一覧から外れる。
        XCTAssertTrue(element(labelContaining: "聞きたいこと（0件）", in: app).waitForExistence(timeout: timeout))

        // 健診の記録で見る。
        app.tabBars.buttons["健診の記録"].tap()
        XCTAssertTrue(element(labelContaining: "様子見でよい", in: app).waitForExistence(timeout: timeout))

        // 元に戻すと、書いた内容のままメモのシートが開き直す（R-17）。
        app.buttons["元に戻す"].firstMatch.tap()
        let reopenedBody = field("memoBodyField", in: app)
        XCTAssertTrue(reopenedBody.waitForExistence(timeout: timeout))
        XCTAssertEqual(reopenedBody.value as? String, "様子見でよい")
        app.buttons["閉じる"].firstMatch.tap()

        // メモは消え、質問は丸付きで「聞きたいこと」に戻る。
        XCTAssertTrue(element(labelContaining: "まだ健診後メモはありません", in: app).waitForExistence(timeout: timeout))
        app.tabBars.buttons["健診予定"].tap()
        XCTAssertTrue(app.buttons["聞いた"].firstMatch.waitForExistence(timeout: timeout))
    }

    /// 入力 → アプリを終了 → 起動し直す → 残っている（S-07、R-72）。
    @MainActor
    func testKeepsWhatWasWrittenAfterRelaunch() throws {
        var app = launch(resettingData: true)
        skipOnboarding(app)

        // 保存した質問と、書きかけの新しい質問を作る。
        addQuestion("腰の痛み", in: app)
        XCTAssertTrue(element(labelContaining: "腰の痛み", in: app).waitForExistence(timeout: timeout))
        app.buttons["質問を追加"].tap()
        let draft = field("questionTextField", in: app)
        XCTAssertTrue(draft.waitForExistence(timeout: timeout))
        draft.tap()
        draft.typeText("お腹の張り")
        // 書きかけは、入力が 1 秒ほど止まったら保存される。余裕を持って待つ。
        Thread.sleep(forTimeInterval: 3)

        // 閉じずにアプリを終了し、同じ保存場所で起動し直す。
        app.terminate()
        app = launch(resettingData: false)

        // 「はじめに」はもう出ず、保存した質問が残っている。
        XCTAssertTrue(element(labelContaining: "腰の痛み", in: app).waitForExistence(timeout: timeout))
        XCTAssertFalse(app.buttons["あとで入れる"].exists)

        // 書きかけの質問も残っている。
        app.buttons["質問を追加"].tap()
        let restored = field("questionTextField", in: app)
        XCTAssertTrue(restored.waitForExistence(timeout: timeout))
        XCTAssertEqual(restored.value as? String, "お腹の張り")
    }

    /// タスクを追加（期限は今日）→ 緑のチェック → 完了にする → 元に戻す（5.10、R-101〜R-104）。
    @MainActor
    func testAddsCompletesAndUndoesATodo() throws {
        let app = launch(resettingData: true)
        skipOnboarding(app)

        // 「タスク」のタブを開き、タスクを追加する。
        app.tabBars.buttons["タスク"].tap()
        let addButton = app.buttons["タスクを追加"]
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        addButton.tap()
        let input = field("todoTitleField", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: timeout))
        input.tap()
        input.typeText("母親学級の申し込み")

        // 期限のボタンで「今日」を選ぶと、選んだ期限が文で出る（R-102）。
        app.buttons["今日"].firstMatch.tap()
        XCTAssertTrue(element(labelContaining: "期限：", in: app).waitForExistence(timeout: timeout))
        app.buttons["追加"].tap()
        XCTAssertTrue(element(labelContaining: "母親学級の申し込み", in: app).waitForExistence(timeout: timeout))

        // 丸を押すと緑のチェックが付き、その場に残る。下のボタンで完了にする（R-104）。
        app.buttons["チェックなし"].firstMatch.tap()
        let completeButton = app.buttons["チェックした 1 件を完了にする"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: timeout))
        completeButton.tap()
        XCTAssertTrue(element(labelContaining: "完了したタスク（1 件）", in: app).waitForExistence(timeout: timeout))

        // 元に戻すと、チェックが付いた状態で一覧に戻る。
        app.buttons["元に戻す"].firstMatch.tap()
        XCTAssertTrue(app.buttons["チェックあり"].firstMatch.waitForExistence(timeout: timeout))
    }

    // MARK: - 手順

    /// 画面のテスト用の保存場所で起動する。
    @MainActor
    private func launch(resettingData: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (resettingData ? ["-ui-testing-reset"] : [])
        app.launch()
        return app
    }

    /// 初めて開いたときの「はじめに」を、「あとで入れる」で閉じる。
    @MainActor
    private func skipOnboarding(_ app: XCUIApplication) {
        let later = app.buttons["あとで入れる"]
        XCTAssertTrue(later.waitForExistence(timeout: timeout))
        later.tap()
    }

    /// 「＋ 質問を追加」から質問を 1 つ足す。
    @MainActor
    private func addQuestion(_ text: String, in app: XCUIApplication) {
        app.buttons["質問を追加"].tap()
        let input = field("questionTextField", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: timeout))
        input.tap()
        input.typeText(text)
        app.buttons["追加"].tap()
    }

    /// 名前（accessibilityIdentifier）で入力欄を探す。1 行の欄か、複数行の欄かは問わない。
    @MainActor
    private func field(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 画面に出る言葉を含むものを探す。行全体が 1 つのボタンになっているときも見つかるようにする。
    @MainActor
    private func element(labelContaining text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
