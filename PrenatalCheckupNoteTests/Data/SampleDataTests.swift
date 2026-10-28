import Foundation
import Testing
import UIKit
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

    @Test func newestMemoHasTwoSamplePictures() throws {
        // 写真の機能を見せるため、2 週間前のメモにだけ見本の絵を 2 枚付ける（段階 F3）。
        let service = try seededService()
        let memos = try service.memos()
        let newest = try #require(memos.first { $0.visitDay == today.adding(days: -14) })

        let photos = try service.photos(memoID: newest.id)
        #expect(photos.count == 2)
        #expect(photos.allSatisfy { UIImage(data: $0.imageData) != nil && UIImage(data: $0.thumbnailData) != nil })
        // 小さい画像は、大きい画像より小さい（一覧で大きい画像を読み込まないため）。
        #expect(photos.allSatisfy { $0.thumbnailData.count < $0.imageData.count })

        for memo in memos where memo.id != newest.id {
            #expect(try service.photos(memoID: memo.id).isEmpty)
        }
    }

    @Test func hasTodosForEverySection() throws {
        // 紹介動画で、タスクの一覧のまとまり・緑のチェック・完了・健診後メモからの追加が一通り見えること（ToDo 4）。
        let service = try seededService()
        let todos = try service.todos()
        let entries = todos.map(\.listEntry)
        let nextCheckupDay = today.adding(days: 14)

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nextCheckupDay)
        #expect(sections.map(\.kind) == [
            .noDue,
            .overdue,
            .day(today, isNextCheckupDay: false),
            .day(today.adding(days: 7), isNextCheckupDay: false),
            .day(nextCheckupDay, isNextCheckupDay: true),
        ])
        #expect(TodoList.checkedCount(entries) == 1)
        #expect(TodoList.completed(entries).count == 1)
        #expect(TodoList.badgeCount(entries, today: today) == 3)
        let summary = try #require(TodoList.nextCheckupSummary(entries, today: today, nextCheckupDay: nextCheckupDay))
        #expect(summary.count == 5)
        #expect(summary.overdueCount == 1)

        // 健診後メモから追加したタスクは、そのメモの画面に並ぶ。
        let memos = try service.memos()
        let newest = try #require(memos.first { $0.visitDay == today.adding(days: -14) })
        let older = try #require(memos.first { $0.visitDay == today.adding(days: -42) })
        #expect(todos.filter { $0.originMemoID == newest.id }.map(\.title) == ["血液検査の受診票に記入する"])
        #expect(todos.filter { $0.originMemoID == older.id }.map(\.isCompleted) == [true])
        #expect(todos.filter { $0.originMemoID != nil }.allSatisfy { TodoList.originText($0.listEntry) != nil })
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
