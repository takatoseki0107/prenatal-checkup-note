import Foundation

extension Calendar {
    /// アプリの日付の計算に使う暦。グレゴリオ暦・日本時間（Asia/Tokyo）に固定する。要件定義 v0.4 R-90、ADR 0006。
    ///
    /// iPhone の地域や時間帯の設定によらず、「今日」と健診の日付、お知らせの時刻を同じ基準で決めるため。
    nonisolated static let japan: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()
}

/// 時刻を持たない日付（年・月・日）。受診日や出産予定日に使う。要件定義 v0.4 R-91、ADR 0006。
///
/// `Date` で持つと、時間帯が変わったときに日付が 1 日ずれることがあるため、年・月・日で持つ。
/// 時刻と組み合わせるときだけ、`Calendar.japan` で `Date` にする。
nonisolated struct CalendarDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    /// 実在する日付のときだけ作れる。例：2026 年 2 月 30 日は作れない。
    init?(year: Int, month: Int, day: Int, calendar: Calendar = .japan) {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else {
            return nil
        }
        let made = calendar.dateComponents([.year, .month, .day], from: date)
        guard made.year == year, made.month == month, made.day == day else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// その瞬間が、暦の上で何日にあたるか。
    init(_ date: Date, calendar: Calendar = .japan) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        // 年・月・日は、グレゴリオ暦なら必ず得られる。
        year = components.year ?? 1
        month = components.month ?? 1
        day = components.day ?? 1
    }

    /// 保存用の数（例：2026 年 11 月 5 日なら 20261105）から作る。並べ替えと保存に使う。実在しない日付なら `nil`。
    init?(number: Int, calendar: Calendar = .japan) {
        self.init(year: number / 10_000, month: (number / 100) % 100, day: number % 100, calendar: calendar)
    }

    /// 保存用の数。例：2026 年 11 月 5 日なら 20261105。数の大小が日付の前後と一致する。
    var number: Int {
        year * 10_000 + month * 100 + day
    }

    /// その日の指定の時刻。
    func date(hour: Int = 0, minute: Int = 0, calendar: Calendar = .japan) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        // 実在する日付から作るので、必ず得られる。
        return calendar.date(from: components) ?? .distantPast
    }

    /// 何日か後（負なら前）の日付。
    func adding(days: Int, calendar: Calendar = .japan) -> CalendarDay {
        let moved = calendar.date(byAdding: .day, value: days, to: date(hour: 12, calendar: calendar)) ?? .distantPast
        return CalendarDay(moved, calendar: calendar)
    }

    /// この日から `other` までの日数。`other` が前の日なら負になる。
    func days(until other: CalendarDay, calendar: Calendar = .japan) -> Int {
        let start = date(hour: 12, calendar: calendar)
        let end = other.date(hour: 12, calendar: calendar)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// 例：「2026-10-25」。ログやテストの表示に使う。画面の表示には使わない。
    var description: String {
        String(format: "%04ld-%02ld-%02ld", year, month, day)
    }
}
