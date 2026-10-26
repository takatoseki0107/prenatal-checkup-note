import Foundation

/// 健診後メモを書くシートの決まり（要件定義 v0.4 の 5.2）。画面から切り離して、テストで確かめられるようにする。
nonisolated enum MemoSheetRules {
    /// 受診日の下に出す案内（R-10、R-11）。
    nonisolated enum VisitDayGuide: Equatable {
        /// 案内なし。
        case none
        /// 次の健診の日付を入れている（R-10）。
        case fromNextCheckup
        /// 受診日がまだ先の日（R-11）。`isNextCheckupDay` は、その日が次の健診の日か。
        case future(CalendarDay, isNextCheckupDay: Bool)

        /// 画面に出す文。
        var message: String? {
            switch self {
            case .none:
                nil
            case .fromNextCheckup:
                "「次の健診」の日付を入れています。違う日なら変えられます。"
            case .future(let day, let isNextCheckupDay):
                if isNextCheckupDay {
                    "次の健診（\(day.displayText)）はまだ先です。今日の受診のメモなら、日付を今日にしてください。"
                } else {
                    "受診日（\(day.displayText)）はまだ先です。今日の受診のメモなら、日付を今日にしてください。"
                }
            }
        }
    }

    /// 保存したときに、次の健診がどうなるか（R-15、R-16）。
    nonisolated enum NextCheckupOutcome: Equatable {
        /// 次の健診の日付が入っていない。
        case none
        /// その予定を空にする（持ち物のチェックも外す）。
        case willClear(CalendarDay)
        /// その予定は残る。
        case willKeep(CalendarDay)

        /// 保存ボタンの上に出す 1 行（R-16）。
        var message: String? {
            switch self {
            case .none:
                nil
            case .willClear(let day):
                "保存すると、\(day.displayText)の健診は終わりとして、次の健診の欄を空にします（持ち物のチェックも外します）"
            case .willKeep(let day):
                "次の健診（\(day.displayText)）の予定は残ります"
            }
        }
    }

    /// 受診日の案内（R-10、R-11）。まだ先の日なら、それを先に出す。
    static func visitDayGuide(visitDay: CalendarDay, nextCheckupDay: CalendarDay?, today: CalendarDay) -> VisitDayGuide {
        if visitDay > today {
            return .future(visitDay, isNextCheckupDay: visitDay == nextCheckupDay)
        }
        if visitDay == nextCheckupDay {
            return .fromNextCheckup
        }
        return .none
    }

    /// 保存で次の健診がどうなるか（R-15）。`NoteService.saveMemo` と同じ判定。
    ///
    /// 書き始めたときと同じ予定（ID で比べる）が残っていて、その日と受診日が同じときだけ空にする。
    static func nextCheckupOutcome(
        visitDay: CalendarDay,
        nextCheckupIDAtStart: UUID?,
        currentNextCheckupID: UUID?,
        currentNextCheckupDay: CalendarDay?
    ) -> NextCheckupOutcome {
        guard let currentNextCheckupID, let currentNextCheckupDay else {
            return .none
        }
        if currentNextCheckupID == nextCheckupIDAtStart, currentNextCheckupDay == visitDay {
            return .willClear(currentNextCheckupDay)
        }
        return .willKeep(currentNextCheckupDay)
    }

    /// 保存ボタンの文（R-14）。
    static func saveButtonTitle(includedQuestionCount: Int) -> String {
        includedQuestionCount > 0 ? "メモと質問 \(includedQuestionCount) 件を保存" : "メモを保存"
    }

    /// 保存できるか（R-12）。本文・「この健診で聞いたこと」・写真のどれかが要る（写真は段階 E で足した）。空白や改行だけの本文は空。
    static func canSave(body: String, includedQuestionCount: Int, photoCount: Int = 0) -> Bool {
        InputText.normalized(body) != nil || includedQuestionCount > 0 || photoCount > 0
    }

    /// 「次の健診」の画面の下の、健診後メモの入口（R-20）。
    nonisolated enum Entry: Equatable {
        /// 出さない。
        case hidden
        /// 「健診後メモを書く」。
        case write
        /// 「入力途中のメモを続ける」。
        case continueDraft

        var title: String? {
            switch self {
            case .hidden:
                nil
            case .write:
                "健診後メモを書く"
            case .continueDraft:
                "入力途中のメモを続ける"
            }
        }
    }

    /// 入口を出すか（R-20）。次の健診の日付・丸を付けた質問・入力途中のメモのどれかがあるときだけ出す。
    static func entry(hasNextCheckup: Bool, hasAskedQuestion: Bool, hasDraft: Bool) -> Entry {
        if hasDraft {
            return .continueDraft
        }
        if hasNextCheckup || hasAskedQuestion {
            return .write
        }
        return .hidden
    }
}
