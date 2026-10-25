import Testing
@testable import PrenatalCheckupNote

/// 前日の夜のお知らせの時刻（R-40〜R-42）を確かめる。
struct ReminderTimeRuleTests {
    private typealias Slot = ReminderTimeRule.Slot

    private let checkupDay = TestDates.day(2026, 11, 5)

    @Test func offersEveningSlotsEveryThirtyMinutes() {
        let slots = ReminderTimeRule.allSlots

        #expect(slots.count == 12)
        #expect(slots.first == Slot(hour: 18, minute: 0))
        #expect(slots.last == Slot(hour: 23, minute: 30))
        #expect(slots.contains(ReminderTimeRule.defaultSlot))
        #expect(ReminderTimeRule.defaultSlot.description == "21:00")
    }

    @Test func firesOnTheDayBefore() {
        let fire = ReminderTimeRule.fireDate(for: checkupDay, at: Slot(hour: 21, minute: 0))

        #expect(fire == TestDates.tokyo(2026, 11, 4, 21, 0))
    }

    @Test func hidesSlotsThatHavePassed() {
        let now = TestDates.tokyo(2026, 11, 4, 21, 10)

        let available = ReminderTimeRule.availableSlots(for: checkupDay, now: now)

        #expect(available.first == Slot(hour: 21, minute: 30))
        #expect(available.count == 5)
    }

    @Test func treatsTheExactMinuteAsPassed() {
        let now = TestDates.tokyo(2026, 11, 4, 21, 0)

        let available = ReminderTimeRule.availableSlots(for: checkupDay, now: now)

        #expect(!available.contains(Slot(hour: 21, minute: 0)))
        #expect(available.first == Slot(hour: 21, minute: 30))
    }

    @Test func offersEverySlotWellBefore() {
        let now = TestDates.tokyo(2026, 10, 25, 9, 0)

        #expect(ReminderTimeRule.availableSlots(for: checkupDay, now: now).count == 12)
    }

    @Test func keepsTheSelectedSlotWhileItIsAvailable() {
        let now = TestDates.tokyo(2026, 11, 4, 20, 0)

        let result = ReminderTimeRule.adjust(Slot(hour: 21, minute: 0), for: checkupDay, now: now)

        #expect(result == .unchanged(Slot(hour: 21, minute: 0)))
    }

    @Test func movesToTheEarliestAvailableSlot() {
        let now = TestDates.tokyo(2026, 11, 4, 21, 10)

        let result = ReminderTimeRule.adjust(Slot(hour: 19, minute: 0), for: checkupDay, now: now)

        #expect(result == .moved(from: Slot(hour: 19, minute: 0), to: Slot(hour: 21, minute: 30)))
    }

    @Test func refusesWhenNoSlotIsLeft() {
        let now = TestDates.tokyo(2026, 11, 4, 23, 40)

        #expect(ReminderTimeRule.adjust(ReminderTimeRule.defaultSlot, for: checkupDay, now: now) == .unavailable)
        #expect(ReminderTimeRule.adjust(ReminderTimeRule.defaultSlot, for: TestDates.day(2026, 10, 25), now: now) == .unavailable)
    }
}
