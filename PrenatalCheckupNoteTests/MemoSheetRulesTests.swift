import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 健診後メモを書くシートの決まり（要件定義 v0.4 の 5.2）を確かめる。
struct MemoSheetRulesTests {
    private let today = TestDates.day(2026, 10, 25)

    // MARK: - 受診日の案内（R-10、R-11）

    @Test func saysTheVisitDayCameFromTheNextCheckup() {
        let guide = MemoSheetRules.visitDayGuide(visitDay: today, nextCheckupDay: today, today: today)
        #expect(guide == .fromNextCheckup)
        #expect(guide.message == "「次の健診」の日付を入れています。違う日なら変えられます。")
    }

    @Test func warnsWhenTheNextCheckupIsStillAhead() {
        let nextDay = TestDates.day(2026, 10, 29)
        let guide = MemoSheetRules.visitDayGuide(visitDay: nextDay, nextCheckupDay: nextDay, today: today)
        #expect(guide == .future(nextDay, isNextCheckupDay: true))
        #expect(guide.message == "次の健診（10月29日（木））はまだ先です。今日の受診のメモなら、日付を今日にしてください。")
    }

    @Test func warnsWhenAChosenDayIsStillAhead() {
        let chosen = TestDates.day(2026, 10, 30)
        let guide = MemoSheetRules.visitDayGuide(visitDay: chosen, nextCheckupDay: nil, today: today)
        #expect(guide == .future(chosen, isNextCheckupDay: false))
        #expect(guide.message == "受診日（10月30日（金））はまだ先です。今日の受診のメモなら、日付を今日にしてください。")
    }

    @Test func saysNothingForAPastOrTodaysVisit() {
        #expect(MemoSheetRules.visitDayGuide(visitDay: today, nextCheckupDay: nil, today: today) == .none)
        let yesterday = TestDates.day(2026, 10, 24)
        #expect(MemoSheetRules.visitDayGuide(visitDay: yesterday, nextCheckupDay: today, today: today) == .none)
    }

    // MARK: - 次の健診がどうなるか（R-15、R-16）

    @Test func clearsTheSameNextCheckupOnTheSameDay() {
        let id = UUID()
        let outcome = MemoSheetRules.nextCheckupOutcome(
            visitDay: today, nextCheckupIDAtStart: id, currentNextCheckupID: id, currentNextCheckupDay: today
        )
        #expect(outcome == .willClear(today))
        #expect(outcome.message == "保存すると、10月25日（日）の健診は終わりとして、次の健診の欄を空にします（持ち物のチェックも外します）")
    }

    @Test func keepsTheNextCheckupOnAnotherDay() {
        let id = UUID()
        let nextDay = TestDates.day(2026, 11, 8)
        let outcome = MemoSheetRules.nextCheckupOutcome(
            visitDay: today, nextCheckupIDAtStart: id, currentNextCheckupID: id, currentNextCheckupDay: nextDay
        )
        #expect(outcome == .willKeep(nextDay))
        #expect(outcome.message == "次の健診（11月8日（日））の予定は残ります")
    }

    @Test func keepsANextCheckupThatWasReplacedWhileWriting() {
        // 書いている間に、予定が別のもの（別の ID）に替わっていたら、同じ日でも空にしない。
        let outcome = MemoSheetRules.nextCheckupOutcome(
            visitDay: today, nextCheckupIDAtStart: UUID(), currentNextCheckupID: UUID(), currentNextCheckupDay: today
        )
        #expect(outcome == .willKeep(today))
    }

    @Test func saysNothingWithoutANextCheckup() {
        let outcome = MemoSheetRules.nextCheckupOutcome(
            visitDay: today, nextCheckupIDAtStart: nil, currentNextCheckupID: nil, currentNextCheckupDay: nil
        )
        #expect(outcome == .none)
        #expect(outcome.message == nil)
    }

    // MARK: - 保存ボタン（R-12、R-14）

    @Test func namesTheSaveButtonByTheNumberOfQuestions() {
        #expect(MemoSheetRules.saveButtonTitle(includedQuestionCount: 2) == "メモと質問 2 件を保存")
        #expect(MemoSheetRules.saveButtonTitle(includedQuestionCount: 0) == "メモを保存")
    }

    @Test func needsABodyOrAQuestionToSave() {
        #expect(MemoSheetRules.canSave(body: "様子見でよい", includedQuestionCount: 0))
        #expect(MemoSheetRules.canSave(body: "", includedQuestionCount: 1))
        #expect(!MemoSheetRules.canSave(body: " \n ", includedQuestionCount: 0))
    }

    // MARK: - 入口（R-20）

    @Test func showsTheEntryOnlyWhenThereIsSomethingToWrite() {
        #expect(MemoSheetRules.entry(hasNextCheckup: false, hasAskedQuestion: false, hasDraft: false) == .hidden)
        #expect(MemoSheetRules.entry(hasNextCheckup: true, hasAskedQuestion: false, hasDraft: false) == .write)
        #expect(MemoSheetRules.entry(hasNextCheckup: false, hasAskedQuestion: true, hasDraft: false) == .write)
        #expect(MemoSheetRules.entry(hasNextCheckup: false, hasAskedQuestion: false, hasDraft: true) == .continueDraft)
        #expect(MemoSheetRules.Entry.continueDraft.title == "入力途中のメモを続ける")
        #expect(MemoSheetRules.Entry.write.title == "健診後メモを書く")
    }
}
