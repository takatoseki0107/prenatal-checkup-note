import Foundation

/// 前日の夜のお知らせの時刻の決まり。要件定義 v0.4 R-40〜R-42。
nonisolated enum ReminderTimeRule {
    /// お知らせの時刻（前日の何時何分か）。
    nonisolated struct Slot: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
        let hour: Int
        let minute: Int

        static func < (lhs: Slot, rhs: Slot) -> Bool {
            (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
        }

        /// 例：「21:00」。
        var description: String {
            String(format: "%02ld:%02ld", hour, minute)
        }
    }

    /// 選び直した結果（R-42）。
    nonisolated enum Adjustment: Hashable, Sendable {
        /// 選んでいた時刻のままでよい。
        case unchanged(Slot)
        /// 選んでいた時刻が過ぎたので、選べるいちばん早い時刻に直した。画面で知らせる。
        case moved(from: Slot, to: Slot)
        /// 選べる時刻が 1 つもない。この予定にはお知らせを設定できない。
        case unavailable
    }

    /// 選べる時刻。前日の 18:00〜23:30 を 30 分ごと（R-40）。
    static let allSlots: [Slot] = (18...23).flatMap { hour in
        [Slot(hour: hour, minute: 0), Slot(hour: hour, minute: 30)]
    }

    /// 最初に選ばれている時刻。
    static let defaultSlot = Slot(hour: 21, minute: 0)

    /// 健診の日の前日の、その時刻。
    static func fireDate(for checkupDay: CalendarDay, at slot: Slot, calendar: Calendar = .japan) -> Date {
        checkupDay.adding(days: -1, calendar: calendar).date(hour: slot.hour, minute: slot.minute, calendar: calendar)
    }

    /// まだ過ぎていない時刻だけを返す（R-41）。ちょうど今の時刻も、過ぎたものとして扱う。
    static func availableSlots(for checkupDay: CalendarDay, now: Date, calendar: Calendar = .japan) -> [Slot] {
        allSlots.filter { fireDate(for: checkupDay, at: $0, calendar: calendar) > now }
    }

    /// 選んでいた時刻が今も使えるかを確かめる。保存の直前にも使う（R-41）。
    static func adjust(_ selected: Slot, for checkupDay: CalendarDay, now: Date, calendar: Calendar = .japan) -> Adjustment {
        let available = availableSlots(for: checkupDay, now: now, calendar: calendar)
        guard let earliest = available.first else {
            return .unavailable
        }
        if available.contains(selected) {
            return .unchanged(selected)
        }
        return .moved(from: selected, to: earliest)
    }
}
