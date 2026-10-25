import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 次の健診のお知らせの決まり（R-40〜R-45、S-05・S-06）を確かめる。
struct ReminderPlanTests {
    private let checkupDay = TestDates.day(2026, 11, 8)
    private let slot = ReminderTimeRule.Slot(hour: 21, minute: 0)
    private let now = TestDates.tokyo(2026, 10, 25, 11, 0)

    @Test func plansTheReminderTheNightBefore() throws {
        let input = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: true)
        let reminder = try #require(ReminderPlan.plannedReminder(input: input, isAuthorized: true, now: now))

        #expect(reminder.fireDate == TestDates.tokyo(2026, 11, 7, 21, 0))
        #expect(reminder.identifier == "next-checkup-reminder-202611072100")
        #expect(reminder.body == "明日は健診の日です。聞きたいことを確かめておきましょう")
    }

    @Test func plansNothingWhenOffUnauthorizedOrMissing() {
        let off = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: false)
        let on = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: true)

        #expect(ReminderPlan.plannedReminder(input: off, isAuthorized: true, now: now) == nil)
        #expect(ReminderPlan.plannedReminder(input: on, isAuthorized: false, now: now) == nil)
        #expect(ReminderPlan.plannedReminder(input: nil, isAuthorized: true, now: now) == nil)
    }

    @Test func plansNothingWhenTheTimeHasPassed() {
        // 前日の 21:00 を過ぎたら、遅れて届かせない（R-41）。
        let input = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: true)
        let justAfter = TestDates.tokyo(2026, 11, 7, 21, 0)
        #expect(ReminderPlan.plannedReminder(input: input, isAuthorized: true, now: justAfter) == nil)
    }

    @Test func schedulesWhatIsMissing() {
        let desired = PlannedReminder(identifier: "next-checkup-reminder-202611072100", fireDate: .now, body: "")
        let actions = ReminderPlan.actions(desired: desired, pendingIdentifiers: [])
        #expect(actions.toCancel.isEmpty)
        #expect(actions.toSchedule == desired)
    }

    @Test func leavesAnAlreadyScheduledReminderAlone() {
        let desired = PlannedReminder(identifier: "next-checkup-reminder-202611072100", fireDate: .now, body: "")
        let actions = ReminderPlan.actions(desired: desired, pendingIdentifiers: [desired.identifier])
        #expect(actions.toCancel.isEmpty)
        #expect(actions.toSchedule == nil)
    }

    @Test func replacesAnOldReminderAndKeepsOthersApps() {
        // 日時を変えたら、古い名前のお知らせは取り消す。このアプリのもの以外には触れない。
        let desired = PlannedReminder(identifier: "next-checkup-reminder-202611212100", fireDate: .now, body: "")
        let actions = ReminderPlan.actions(
            desired: desired,
            pendingIdentifiers: ["next-checkup-reminder-202611072100", "something-else"]
        )
        #expect(actions.toCancel == ["next-checkup-reminder-202611072100"])
        #expect(actions.toSchedule == desired)
    }

    @Test func cancelsEverythingOursWhenNothingIsWanted() {
        let actions = ReminderPlan.actions(
            desired: nil,
            pendingIdentifiers: ["next-checkup-reminder-202611072100", "next-checkup-reminder-202611212100"]
        )
        #expect(actions.toCancel == ["next-checkup-reminder-202611072100", "next-checkup-reminder-202611212100"])
        #expect(actions.toSchedule == nil)
    }
}
