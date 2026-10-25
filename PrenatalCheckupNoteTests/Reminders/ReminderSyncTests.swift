import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 偽物の通知の仕組み。予約中のお知らせを覚え、失敗も起こせる（S-08）。
@MainActor
final class FakeReminderCenter: ReminderCenter {
    var authorization: ReminderAuthorization = .authorized
    var grantsAuthorization = true
    var failsScheduling = false
    private(set) var pending: [String: PlannedReminder] = [:]
    private(set) var scheduleCount = 0

    func authorizationStatus() async -> ReminderAuthorization {
        authorization
    }

    func requestAuthorization() async -> Bool {
        authorization = grantsAuthorization ? .authorized : .denied
        return grantsAuthorization
    }

    func pendingIdentifiers() async -> [String] {
        Array(pending.keys)
    }

    func schedule(_ reminder: PlannedReminder) async throws {
        scheduleCount += 1
        if failsScheduling {
            throw ReminderScheduleError()
        }
        pending[reminder.identifier] = reminder
    }

    func cancel(identifiers: [String]) {
        for identifier in identifiers {
            pending[identifier] = nil
        }
    }
}

/// お知らせをデータに合わせる係（S-05・S-06・S-09）を、偽物の通知の仕組みで確かめる。
@MainActor
struct ReminderSyncTests {
    private let now = TestDates.tokyo(2026, 10, 25, 11, 0)
    private let slot = ReminderTimeRule.Slot(hour: 21, minute: 0)

    /// 「次の健診」の値を外から入れ替えられる、テスト用の入れ物。
    final class InputBox {
        var input: ReminderInput?
    }

    private func makeSync(center: FakeReminderCenter, box: InputBox) -> ReminderSync {
        let now = now
        return ReminderSync(center: center, now: { now }, currentInput: { box.input })
    }

    @Test func schedulesTheReminderForTheNextCheckup() async {
        let center = FakeReminderCenter()
        let box = InputBox()
        box.input = ReminderInput(checkupDay: TestDates.day(2026, 11, 8), slot: slot, isOn: true)
        let sync = makeSync(center: center, box: box)

        sync.requestSync()
        await sync.waitUntilIdle()

        #expect(Array(center.pending.keys) == ["next-checkup-reminder-202611072100"])
        #expect(!sync.lastScheduleFailed)
    }

    @Test func movesTheReminderWhenTheDateChanges() async {
        let center = FakeReminderCenter()
        let box = InputBox()
        box.input = ReminderInput(checkupDay: TestDates.day(2026, 11, 8), slot: slot, isOn: true)
        let sync = makeSync(center: center, box: box)
        sync.requestSync()
        await sync.waitUntilIdle()

        box.input = ReminderInput(checkupDay: TestDates.day(2026, 11, 22), slot: slot, isOn: true)
        sync.requestSync()
        await sync.waitUntilIdle()

        #expect(Array(center.pending.keys) == ["next-checkup-reminder-202611212100"])
    }

    @Test func cancelsWhenTheNextCheckupIsCleared() async {
        let center = FakeReminderCenter()
        let box = InputBox()
        box.input = ReminderInput(checkupDay: TestDates.day(2026, 11, 8), slot: slot, isOn: true)
        let sync = makeSync(center: center, box: box)
        sync.requestSync()
        await sync.waitUntilIdle()

        box.input = nil
        sync.requestSync()
        await sync.waitUntilIdle()

        #expect(center.pending.isEmpty)
    }

    @Test func endsWithTheLatestDataWhenAskedRepeatedly() async {
        // 続けて頼んでも、処理は 1 つずつ行い、最後は最新のデータに合う（S-09）。
        let center = FakeReminderCenter()
        let box = InputBox()
        let sync = makeSync(center: center, box: box)

        box.input = ReminderInput(checkupDay: TestDates.day(2026, 11, 8), slot: slot, isOn: true)
        sync.requestSync()
        box.input = ReminderInput(checkupDay: TestDates.day(2026, 11, 22), slot: slot, isOn: true)
        sync.requestSync()
        box.input = nil
        sync.requestSync()
        await sync.waitUntilIdle()

        #expect(center.pending.isEmpty)
    }

    @Test func doesNotScheduleWithoutPermission() async {
        let center = FakeReminderCenter()
        center.authorization = .denied
        let box = InputBox()
        box.input = ReminderInput(checkupDay: TestDates.day(2026, 11, 8), slot: slot, isOn: true)
        let sync = makeSync(center: center, box: box)

        sync.requestSync()
        await sync.waitUntilIdle()

        #expect(center.pending.isEmpty)
        #expect(sync.authorization == .denied)
    }

    @Test func schedulesAfterPermissionIsGranted() async {
        let center = FakeReminderCenter()
        center.authorization = .notDetermined
        let box = InputBox()
        box.input = ReminderInput(checkupDay: TestDates.day(2026, 11, 8), slot: slot, isOn: true)
        let sync = makeSync(center: center, box: box)

        let granted = await sync.requestAuthorization()
        await sync.waitUntilIdle()

        #expect(granted)
        #expect(sync.authorization == .authorized)
        #expect(center.pending.count == 1)
    }

    @Test func reportsAFailedScheduleAndRecoversNextTime() async {
        let center = FakeReminderCenter()
        center.failsScheduling = true
        let box = InputBox()
        box.input = ReminderInput(checkupDay: TestDates.day(2026, 11, 8), slot: slot, isOn: true)
        let sync = makeSync(center: center, box: box)

        sync.requestSync()
        await sync.waitUntilIdle()
        #expect(sync.lastScheduleFailed)
        #expect(center.pending.isEmpty)

        // 前面に戻ったときなどに合わせ直すと、予約できる（S-06）。
        center.failsScheduling = false
        sync.requestSync()
        await sync.waitUntilIdle()
        #expect(!sync.lastScheduleFailed)
        #expect(center.pending.count == 1)
    }

    @Test func storeAsksForASyncAfterEachOperation() async throws {
        // 保存の窓口を通した操作のあとに、お知らせが合わせられる（S-05）。
        let store = try TemporaryStore()
        let service = store.makeService()
        let noteStore = NoteStore(container: store.container, service: service, undoDisplayDuration: .seconds(60))
        let center = FakeReminderCenter()
        let now = now
        let sync = ReminderSync(center: center, now: { now }, currentInput: { [weak noteStore] in noteStore?.reminderInput })
        noteStore.reminders = sync

        noteStore.perform {
            try $0.setNextCheckup(day: TestDates.day(2026, 11, 8), hour: 10, minute: 30, isReminderOn: true, reminderSlot: ReminderTimeRule.defaultSlot)
        }
        await sync.waitUntilIdle()
        #expect(center.pending.count == 1)

        noteStore.perform { try $0.clearNextCheckup() }
        await sync.waitUntilIdle()
        #expect(center.pending.isEmpty)

        // 元に戻すで予定が戻ったら、お知らせも予約し直す（R-45）。
        noteStore.perform { try $0.undo() }
        await sync.waitUntilIdle()
        #expect(center.pending.count == 1)
    }
}
