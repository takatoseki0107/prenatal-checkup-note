import Foundation
import SwiftData

/// 起動したときに、保存場所を開いて準備する。
enum AppLaunch {
    case ready(NoteStore)
    case failed(String)

    /// - Parameter showsSampleData: 開発用の「サンプルデータを表示する」。`true` なら、別の保存場所に例のデータを入れて開き、
    ///   お知らせは iPhone の通知に触れない窓口を使う（段階 D）。リリースビルドでは無視する。
    static func start(
        now: Date = .now,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        showsSampleData: Bool = false
    ) -> AppLaunch {
        let options = LaunchOptions(arguments: arguments)
        #if DEBUG
        let usesSampleData = showsSampleData
        #else
        let usesSampleData = false
        #endif
        do {
            let container: ModelContainer
            let reminderCenter: any ReminderCenter
            if usesSampleData {
                container = try AppDataStore.makeSampleContainer()
                try SampleData.seed(into: ModelContext(container), today: CalendarDay(now), now: now)
                reminderCenter = SampleReminderCenter()
            } else {
                container = try options.makeContainer()
                reminderCenter = SystemReminderCenter()
            }
            let service = NoteService(context: ModelContext(container), persist: savesData)
            try service.prepareInitialData(now: now)
            let store = NoteStore(container: container, service: service, undoDisplayDuration: options.undoDisplayDuration)
            // お知らせは、いまの「次の健診」に合わせる（S-06）。アプリを開いたときにも一度合わせる。
            let reminders = ReminderSync(center: reminderCenter, currentInput: { [weak store] in
                store?.reminderInput
            })
            store.reminders = reminders
            reminders.requestSync()
            return .ready(store)
        } catch {
            return .failed("データの保存場所を開けませんでした。アプリを終了して、開き直してください。")
        }
    }

    /// 保存の処理。開発用ビルドでは、開発用メニューから失敗させられる（S-08）。
    private static func savesData(_ context: ModelContext) throws {
        #if DEBUG
        if DeveloperSettings.shared.failsSaving {
            throw DeveloperSettings.SaveFailure()
        }
        #endif
        try context.save()
    }
}

/// 起動のときに渡される合図（引数）。画面のテスト（XCUITest）のときだけ使う。
///
/// 画面のテストでは、本当のデータに触れないよう、別の保存場所を使う。開発用ビルドのときだけ効き、リリースビルドでは無視する。
struct LaunchOptions {
    /// 画面のテスト用の保存場所を使う。
    static let uiTestingArgument = "-ui-testing"
    /// 画面のテスト用の保存場所を、開く前に空にする（テストを毎回同じ状態から始めるため）。
    static let resetDataArgument = "-ui-testing-reset"

    /// ふだんの、元に戻すの帯を出しておく長さ（R-60、目安 6 秒）。
    static let undoDisplayDuration: Duration = .seconds(6)
    /// 画面のテストでの長さ。CI のシミュレーターは遅いことがあり、操作の前に帯が消えないようにする。
    /// 帯が時間で消えることは、`NoteStoreTests` で確かめている。
    static let uiTestingUndoDisplayDuration: Duration = .seconds(60)

    let isUITesting: Bool
    let resetsData: Bool

    init(arguments: [String]) {
        #if DEBUG
        isUITesting = arguments.contains(Self.uiTestingArgument)
        resetsData = isUITesting && arguments.contains(Self.resetDataArgument)
        #else
        isUITesting = false
        resetsData = false
        #endif
    }

    var undoDisplayDuration: Duration {
        isUITesting ? Self.uiTestingUndoDisplayDuration : Self.undoDisplayDuration
    }

    func makeContainer() throws -> ModelContainer {
        if isUITesting {
            return try AppDataStore.makeUITestingContainer(resettingData: resetsData)
        }
        return try AppDataStore.makeAppContainer()
    }
}
