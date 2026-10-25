import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 持ち物（R-34）と、次の健診の日付を消す（R-33）を、一時的なファイルの保存場所で確かめる。
@MainActor
struct BringItemTests {
    private let now = TestDates.tokyo(2026, 10, 25, 11, 0)

    @Test func addsAnItemAtTheBottom() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)

        try service.addBringItem(name: "  お薬手帳 ")

        #expect(try service.bringItems().map(\.name) == ["母子健康手帳", "保険証", "受診票", "お薬手帳"])
        #expect(throws: NoteServiceError.emptyText) {
            try service.addBringItem(name: " \n")
        }
    }

    @Test func bringsBackARemovedItemAsItWas() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        let insurance = try #require(try service.bringItems().first { $0.name == "保険証" })
        try service.setBringItemChecked(true, itemID: insurance.id)

        try service.removeBringItem(id: insurance.id)
        #expect(try service.bringItems().map(\.name) == ["母子健康手帳", "受診票"])
        #expect(service.pendingUndo == .removedBringItem(BringItemSnapshot(id: insurance.id, name: "保険証", isChecked: true, sortOrder: 1)))

        try service.undo()

        let items = try service.bringItems()
        #expect(items.map(\.name) == ["母子健康手帳", "保険証", "受診票"])
        #expect(items.first { $0.name == "保険証" }?.isChecked == true)
    }

    @Test func removedItemStaysRemovedAfterAFailedUndo() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        let card = try #require(try service.bringItems().first)
        try service.removeBringItem(id: card.id)

        store.failures.shouldFail = true
        #expect(throws: NoteServiceError.saveFailed) {
            try service.undo()
        }

        // 戻すのに失敗したら、戻す前のデータのまま。戻すための値も残る（R-63）。
        #expect(try service.bringItems().count == 2)
        #expect(service.pendingUndo != nil)
    }

    @Test func clearsAndBringsBackTheNextCheckup() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let day = TestDates.day(2026, 11, 8)
        let id = try service.setNextCheckup(day: day, hour: 10, minute: 30, isReminderOn: false, reminderSlot: ReminderTimeRule.defaultSlot)

        try service.clearNextCheckup()
        #expect(try service.nextCheckup() == nil)

        try service.undo()
        let next = try #require(try service.nextCheckup())
        #expect(next.id == id)
        #expect(next.day == day)
        #expect(next.hour == 10)
        #expect(next.minute == 30)
    }
}
