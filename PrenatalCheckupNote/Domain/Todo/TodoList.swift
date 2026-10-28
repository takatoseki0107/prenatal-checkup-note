import Foundation

/// やることの一覧の並べ方と数え方（要件定義 v0.4 の 5.10）。画面や保存の仕組みから切り離して、テストで確かめる。
///
/// - いちばん上に「期限なし」、次に「期限を過ぎた」、そのあと期限の日ごとの見出し（R-103）。
/// - 次の健診の日は見出しに「次の健診の日」と添え、その日のやることがなければ「◯月◯日（◯）は次の健診」の線を出す（R-103）。
/// - タブの数は、完了していない「期限を過ぎた」と「今日」のやること（R-106）。
/// - 健診予定のカードの 1 行は、完了していないやることのうち、期限が次の健診の日までのもの（R-110）。
nonisolated enum TodoList {
    /// やること 1 件の値。保存の仕組み（`TodoItem`）から写して渡す。
    nonisolated struct Entry: Equatable, Sendable, Identifiable {
        let id: UUID
        let title: String
        let note: String
        /// 期限の日。期限なしなら `nil`。
        let dueDay: CalendarDay?
        let isStarred: Bool
        /// 緑のチェック（完了の 1 段階目）。
        let isChecked: Bool
        /// 完了にした日時。完了していなければ `nil`。
        let completedAt: Date?
        /// 健診後メモから足したとき、そのメモの受診日（R-107）。
        let originVisitDay: CalendarDay?
        let createdAt: Date

        init(
            id: UUID = UUID(),
            title: String,
            note: String = "",
            dueDay: CalendarDay? = nil,
            isStarred: Bool = false,
            isChecked: Bool = false,
            completedAt: Date? = nil,
            originVisitDay: CalendarDay? = nil,
            createdAt: Date
        ) {
            self.id = id
            self.title = title
            self.note = note
            self.dueDay = dueDay
            self.isStarred = isStarred
            self.isChecked = isChecked
            self.completedAt = completedAt
            self.originVisitDay = originVisitDay
            self.createdAt = createdAt
        }

        var isCompleted: Bool {
            completedAt != nil
        }

        /// 期限を過ぎているか（完了したものは過ぎていない扱い）。
        func isOverdue(today: CalendarDay) -> Bool {
            guard !isCompleted, let dueDay else {
                return false
            }
            return dueDay < today
        }
    }

    /// 一覧のまとまり 1 つ（見出しと、その下のやること）。次の健診の線は、やることを持たない。
    nonisolated struct Section: Equatable, Sendable {
        nonisolated enum Kind: Hashable, Sendable {
            /// 期限なし（いちばん上）。
            case noDue
            /// 期限を過ぎた（オレンジ）。
            case overdue
            /// 期限の日ごとの見出し（今日・明日・それより先の日）。
            case day(CalendarDay, isNextCheckupDay: Bool)
            /// 「── ◯月◯日（◯）は次の健診 ──」の線。その日のやることがないときだけ出す。
            case nextCheckupLine(CalendarDay)
        }

        let kind: Kind
        /// 見出しの文。例：「期限なし」「今日」「11月9日（月）」「11月9日（月）は次の健診」。
        let title: String
        /// 見出しに添える日付（今日・明日のときだけ）。例：「10月27日（火）」。なければ `nil`。
        /// 次の健診の日かどうかは `kind` の `isNextCheckupDay` で見る（画面では、見出しの横に札を付ける）。
        let subtitle: String?
        let entries: [Entry]
    }

    // MARK: - 並べ方（R-103）

    /// 完了していないやることを、見出しごとにまとめる。
    ///
    /// 同じ見出しの中は、星の付いたものが先、そのあと足した順。「期限を過ぎた」だけは、星のあと期限の古い順にする
    /// （行に期限の日を出すので、日付が前後すると読みにくいため）。
    /// 次の健診の線は、次の健診が今日以降で、その日の見出しがなく、期限の日の見出しが 1 つ以上あるときに、日付の順の位置に出す。
    static func sections(_ entries: [Entry], today: CalendarDay, nextCheckupDay: CalendarDay?) -> [Section] {
        let open = entries.filter { !$0.isCompleted }
        var result: [Section] = []

        let noDue = open.filter { $0.dueDay == nil }
        if !noDue.isEmpty {
            result.append(Section(kind: .noDue, title: "期限なし", subtitle: nil, entries: sortedInSection(noDue)))
        }

        let overdue = open.filter { $0.isOverdue(today: today) }
        if !overdue.isEmpty {
            let sorted = overdue.sorted { lhs, rhs in
                if lhs.isStarred != rhs.isStarred {
                    return lhs.isStarred
                }
                if let left = lhs.dueDay, let right = rhs.dueDay, left != right {
                    return left < right
                }
                return isAddedEarlier(lhs, rhs)
            }
            result.append(Section(kind: .overdue, title: "期限を過ぎた", subtitle: nil, entries: sorted))
        }

        let upcoming = open.filter { entry in
            guard let dueDay = entry.dueDay else {
                return false
            }
            return dueDay >= today
        }
        let days = Set(upcoming.compactMap(\.dueDay)).sorted()
        let nextDay = nextCheckupDay.flatMap { $0 >= today ? $0 : nil }
        var needsLine = nextDay.map { !days.contains($0) && !days.isEmpty } ?? false

        for day in days {
            if needsLine, let nextDay, day > nextDay {
                result.append(nextCheckupLine(nextDay))
                needsLine = false
            }
            let isNextCheckupDay = day == nextDay
            result.append(Section(
                kind: .day(day, isNextCheckupDay: isNextCheckupDay),
                title: dayTitle(day, today: today),
                subtitle: daySubtitle(day, today: today),
                entries: sortedInSection(upcoming.filter { $0.dueDay == day })
            ))
        }
        if needsLine, let nextDay {
            result.append(nextCheckupLine(nextDay))
        }
        return result
    }

    /// 完了したこと。完了にした日時の新しい順（R-104）。
    static func completed(_ entries: [Entry]) -> [Entry] {
        entries.filter(\.isCompleted).sorted { lhs, rhs in
            let left = lhs.completedAt ?? .distantPast
            let right = rhs.completedAt ?? .distantPast
            if left != right {
                return left > right
            }
            return isAddedEarlier(lhs, rhs)
        }
    }

    // MARK: - 数え方

    /// 「チェックした n 件を完了にする」の n（R-104）。
    static func checkedCount(_ entries: [Entry]) -> Int {
        entries.filter { $0.isChecked && !$0.isCompleted }.count
    }

    /// 「タスク」のタブに出す数。完了していない「期限を過ぎた」と「今日」のやること（R-106）。
    static func badgeCount(_ entries: [Entry], today: CalendarDay) -> Int {
        entries.filter { entry in
            guard !entry.isCompleted, let dueDay = entry.dueDay else {
                return false
            }
            return dueDay <= today
        }.count
    }

    /// 健診予定のカードに出す「次の健診までのやること」の数（R-110）。
    nonisolated struct NextCheckupSummary: Equatable, Sendable {
        /// 完了していないやることのうち、期限が次の健診の日まで（過ぎたものを含む）の数。
        let count: Int
        /// そのうち、期限を過ぎたものの数。
        let overdueCount: Int

        /// 例：「次の健診までのタスク　4 件」。読み上げの文に使う。
        var title: String {
            "次の健診までのタスク　\(count) 件"
        }

        /// 健診予定のカードの、持ち物と並べたボタンの文。例：「タスク　4 件」。
        /// 持ち物と左右 2 つに並べたので、短くした（2026-10-28、見本 `NextCardLight.dc.html`）。
        var shortTitle: String {
            "タスク　\(count) 件"
        }

        /// 期限を過ぎたものがあるときだけ。例：「期限を過ぎたもの 1 件」。
        var overdueText: String? {
            overdueCount > 0 ? "期限を過ぎたもの \(overdueCount) 件" : nil
        }
    }

    /// 次の健診の日付がない、または数えるものが 0 件なら `nil`（カードに行を出さない）。期限なしのやることは数えない。
    static func nextCheckupSummary(_ entries: [Entry], today: CalendarDay, nextCheckupDay: CalendarDay?) -> NextCheckupSummary? {
        guard let nextCheckupDay else {
            return nil
        }
        let counted = untilNextCheckup(entries, nextCheckupDay: nextCheckupDay)
        guard !counted.isEmpty else {
            return nil
        }
        return NextCheckupSummary(count: counted.count, overdueCount: counted.filter { $0.isOverdue(today: today) }.count)
    }

    /// 次の健診までのやること。完了していないもののうち、期限が次の健診の日まで（過ぎたものを含む）。期限なしは入れない。
    ///
    /// 健診予定のカードの数（R-110）と、カードの「見る」で開いたときの絞り込み（R-111）で、同じものを使う。
    static func untilNextCheckup(_ entries: [Entry], nextCheckupDay: CalendarDay) -> [Entry] {
        entries.filter { entry in
            guard !entry.isCompleted, let dueDay = entry.dueDay else {
                return false
            }
            return dueDay <= nextCheckupDay
        }
    }

    /// 絞り込んでいるときに、一覧の上に出す文（R-111）。例：「次の健診（11月23日）まで」。数は横に大きく出す。
    ///
    /// 画面の題名が「タスク」なので、「のタスク」は付けない（「やること」だったころ、付けると数と並べたときに「やる／こと」で折り返した）。
    static func untilNextCheckupTitle(nextCheckupDay: CalendarDay) -> String {
        "次の健診（\(nextCheckupDay.month)月\(nextCheckupDay.day)日）まで"
    }

    /// 絞り込みをやめるボタンの文（R-111）。ほかに完了していないやることがあれば、その数を出す。
    ///
    /// 「すべて表示」だけだと、ほかにもあるのかがわからず迷う（開発者の指摘）ため、ほかの数を書く。ほかがなければ、一覧に戻るとだけ書く。
    /// 例：「ほかのタスク（1 件）も表示」「タスクの一覧に戻る」。
    static func showOthersButtonTitle(_ entries: [Entry], nextCheckupDay: CalendarDay) -> String {
        let openCount = entries.filter { !$0.isCompleted }.count
        let others = openCount - untilNextCheckup(entries, nextCheckupDay: nextCheckupDay).count
        return others > 0 ? "ほかのタスク（\(others) 件）も表示" : "タスクの一覧に戻る"
    }

    // MARK: - 行と見出しの文

    /// 行に出す期限の文。期限を過ぎたものだけ（ほかは見出しに日付があるので出さない。R-103）。
    /// 例：「10月25日（日）まで（過ぎています）」。
    static func rowDueText(_ entry: Entry, today: CalendarDay) -> String? {
        guard entry.isOverdue(today: today), let dueDay = entry.dueDay else {
            return nil
        }
        return "\(dueDay.displayText)まで（過ぎています）"
    }

    /// 健診後メモから足したやることに出す文（R-107）。例：「10月12日の健診で」。
    static func originText(_ entry: Entry) -> String? {
        entry.originVisitDay.map { "\($0.month)月\($0.day)日の健診で" }
    }

    /// 例：「チェックした 2 件を完了にする」。
    static func completeButtonTitle(checkedCount: Int) -> String {
        "チェックした \(checkedCount) 件を完了にする"
    }

    /// 例：「完了したこと（3 件）」。
    static func completedTitle(count: Int) -> String {
        "完了したタスク（\(count) 件）"
    }

    // MARK: - 内部

    private static func sortedInSection(_ entries: [Entry]) -> [Entry] {
        entries.sorted { lhs, rhs in
            if lhs.isStarred != rhs.isStarred {
                return lhs.isStarred
            }
            return isAddedEarlier(lhs, rhs)
        }
    }

    /// 足した順。同じ日時なら ID の文字の順にして、毎回同じ並びにする。
    private static func isAddedEarlier(_ lhs: Entry, _ rhs: Entry) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func dayTitle(_ day: CalendarDay, today: CalendarDay) -> String {
        switch today.days(until: day) {
        case 0: "今日"
        case 1: "明日"
        default: day.displayText
        }
    }

    private static func daySubtitle(_ day: CalendarDay, today: CalendarDay) -> String? {
        today.days(until: day) <= 1 ? day.displayText : nil
    }

    private static func nextCheckupLine(_ day: CalendarDay) -> Section {
        Section(kind: .nextCheckupLine(day), title: "\(day.displayText)は次の健診", subtitle: nil, entries: [])
    }
}
