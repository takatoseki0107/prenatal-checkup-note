import Foundation
import Testing
@testable import PrenatalCheckupNote

/// サンプルデータ（段階 D）を確かめる。いつ入れても、今日から数えた同じ例になること。
@MainActor
struct SampleDataTests {
    private let now = TestDates.tokyo(2026, 10, 25, 11, 0)
    private let today = TestDates.day(2026, 10, 25)

    private func seededService() throws -> NoteService {
        let store = try TemporaryStore()
        let service = store.makeService()
        try SampleData.seed(into: service.context, today: today, now: now)
        try service.prepareInitialData(now: now)
        return service
    }

    @Test func todayIsWeek24Day3() throws {
        let service = try seededService()
        let profile = try #require(try service.profile())

        #expect(profile.hasFinishedOnboarding)
        #expect(profile.showsGestationalAge)
        #expect(GestationalAgeDisplay.text(on: today, dueDate: profile.dueDate, isShown: true) == "妊娠 24 週 3 日")
    }

    @Test func hasQuestionsMemosAndANextCheckup() throws {
        let service = try seededService()

        let questions = try service.questions()
        #expect(questions.count == 4)
        #expect(questions.filter(\.isStarred).count == 1)

        let memos = try service.memos()
        #expect(memos.count == 3)
        #expect(Set(memos.compactMap(\.visitDay)) == [
            today.adding(days: -14),
            today.adding(days: -42),
            today.adding(days: -70),
        ])
        #expect(memos.allSatisfy { !$0.items.isEmpty && $0.gestationalAgeAtVisit != nil })

        let next = try #require(try service.nextCheckup())
        #expect(next.day == today.adding(days: 14))
        #expect(next.isReminderOn)

        let bringItems = try service.bringItems()
        #expect(bringItems.count == NoteService.initialBringItemNames.count)
        #expect(bringItems.filter(\.isChecked).count == 1)
    }

    @Test func preparingAgainDoesNotAddMore() throws {
        // 起動の準備（`prepareInitialData`）を通しても、持ち物や設定が二重にならない。
        let service = try seededService()
        try service.prepareInitialData(now: now)
        #expect(try service.bringItems().count == NoteService.initialBringItemNames.count)
    }

    @Test func sampleRemindersDoNotTouchTheRealNotifications() async {
        // サンプルの窓口は、予約したことにだけする。許可もあることにする。
        let center = SampleReminderCenter()
        let input = ReminderInput(checkupDay: today.adding(days: 14), slot: ReminderTimeRule.defaultSlot, isOn: true)
        let sync = ReminderSync(center: center, now: { now }, currentInput: { input })

        sync.requestSync()
        await sync.waitUntilIdle()

        #expect(sync.authorization == .authorized)
        #expect(await center.pendingIdentifiers() == ["next-checkup-reminder-202611072100"])
    }
}
