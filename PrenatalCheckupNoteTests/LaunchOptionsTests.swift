import Testing
@testable import PrenatalCheckupNote

/// 起動のときの合図（画面のテスト用）を確かめる。テストは開発用ビルドで動くので、合図が効く。
@MainActor
struct LaunchOptionsTests {
    @Test func usesTheRealStoreWithoutTheSignal() {
        let options = LaunchOptions(arguments: ["PrenatalCheckupNote"])
        #expect(!options.isUITesting)
        #expect(!options.resetsData)
        #expect(options.undoDisplayDuration == .seconds(6))
    }

    @Test func usesTheTestingStoreWithTheSignal() {
        let options = LaunchOptions(arguments: ["PrenatalCheckupNote", "-ui-testing"])
        #expect(options.isUITesting)
        #expect(!options.resetsData)
        #expect(options.undoDisplayDuration == .seconds(60))
    }

    @Test func resetsOnlyTheTestingStore() {
        // 空にする合図だけでは、本当の保存場所を空にしない。
        #expect(!LaunchOptions(arguments: ["-ui-testing-reset"]).resetsData)
        #expect(LaunchOptions(arguments: ["-ui-testing", "-ui-testing-reset"]).resetsData)
    }
}
