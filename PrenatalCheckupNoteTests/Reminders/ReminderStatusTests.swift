import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 次の健診のカードに出す、お知らせの状態と言葉（R-41、R-42、R-44）を確かめる。
struct ReminderStatusTests {
    private let checkupDay = TestDates.day(2026, 11, 8)
    private let slot = ReminderTimeRule.Slot(hour: 21, minute: 0)
    private let now = TestDates.tokyo(2026, 10, 25, 11, 0)

    @Test func showsTheTimeWhenOn() {
        let input = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: true)
        let status = ReminderStatus.make(input: input, authorization: .authorized, now: now)

        #expect(status == .on(slot))
        #expect(status.text == "前日の 21:00 にお知らせ")
        #expect(status.showsSwitchOn)
        #expect(status.canToggle)
    }

    @Test func showsOffWhenOff() {
        let input = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: false)
        let status = ReminderStatus.make(input: input, authorization: .authorized, now: now)

        #expect(status == .off)
        #expect(status.text == "お知らせはオフ")
        #expect(!status.showsSwitchOn)
        #expect(status.canToggle)
    }

    @Test func doesNotLookOnWithoutPermission() {
        // 許可がないときは、オンにしてあってもオンに見せない（R-44）。
        let input = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: true)
        let denied = ReminderStatus.make(input: input, authorization: .denied, now: now)
        let notAsked = ReminderStatus.make(input: input, authorization: .notDetermined, now: now)

        #expect(denied == .notPermitted)
        #expect(notAsked == .notPermitted)
        #expect(denied.text == "お知らせはオフ（通知が許可されていません）")
        #expect(!denied.showsSwitchOn)
    }

    @Test func tellsWhenTheTimeHasPassed() {
        // 前日の 21:00 を過ぎたら、遅れて届かせず、過ぎたことを出す（R-41）。
        let input = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: true)
        let status = ReminderStatus.make(input: input, authorization: .authorized, now: TestDates.tokyo(2026, 11, 7, 21, 0))

        #expect(status == .passed(slot))
        #expect(status.text == "お知らせの時刻（前日の 21:00）を過ぎました")
        #expect(status.showsSwitchOn)
    }

    @Test func cannotTurnOnAfterTheNightBefore() {
        // 前日の 23:30 を過ぎたら、選べる時刻がない（R-41）。
        let input = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: false)
        let status = ReminderStatus.make(input: input, authorization: .authorized, now: TestDates.tokyo(2026, 11, 7, 23, 30))

        #expect(status == .unavailable)
        #expect(status.text == "前日の夜を過ぎたので、お知らせは設定できません")
        #expect(!status.canToggle)
    }

    @Test func canStillTurnOnLateInTheNightBefore() {
        // 前日の 23:00 なら、23:30 がまだ選べる。
        let input = ReminderInput(checkupDay: checkupDay, slot: slot, isOn: false)
        let status = ReminderStatus.make(input: input, authorization: .authorized, now: TestDates.tokyo(2026, 11, 7, 23, 0))

        #expect(status == .off)
    }

    @Test func messagesUseTheMockWording() {
        let from = ReminderTimeRule.Slot(hour: 19, minute: 0)
        let to = ReminderTimeRule.Slot(hour: 21, minute: 30)

        #expect(ReminderTimeRule.movedMessage(from: from, to: to) == "前の時刻（19:00）はもう過ぎているので、21:30 にしました")
        #expect(ReminderTimeRule.unavailableMessage == "この日の前日の夜は、もう過ぎています。この日には、お知らせを設定できません。")
    }
}

/// お知らせを押したときに「次の健診」を開く印（R-46）を確かめる。
@MainActor
struct NotificationTapRelayTests {
    @Test func opensNextCheckupForOurReminder() {
        let relay = NotificationTapRelay()
        relay.receive(identifier: "next-checkup-reminder-202611072100")
        #expect(relay.opensNextCheckup)

        relay.didOpenNextCheckup()
        #expect(!relay.opensNextCheckup)
    }

    @Test func opensNextCheckupForTheTestReminder() {
        // 開発用の「1 分後に試しのお知らせ」も、本物と同じく「次の健診」を開く。
        let relay = NotificationTapRelay()
        relay.receive(identifier: ReminderPlan.testIdentifier)
        #expect(relay.opensNextCheckup)
    }

    @Test func ignoresOtherNotifications() {
        let relay = NotificationTapRelay()
        relay.receive(identifier: "something-else")
        #expect(!relay.opensNextCheckup)
    }
}
