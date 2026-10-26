import Foundation
import SwiftData

/// 面接や紹介動画で見せるための、例のデータ（要件定義 v0.4 の段階 D、6 章）。開発用ビルドの「サンプルデータを表示する」で使う。
///
/// 本当のデータとは別の保存場所（`AppDataStore.makeSampleContainer`）に入れる。本当のデータとお知らせには触れない。
/// 日付は今日から数えて作るので、いつ見せても「今日は妊娠 24 週 3 日、次の健診は 2 週間後」になる。
/// 2 週間前のメモには、コードで描いた見本の絵を 2 枚付ける（段階 F3、`SampleImages`）。本当の写真は使わない。
enum SampleData {
    /// 今日の妊娠週数が 24 週 3 日になる出産予定日（今日から 109 日後。280 − 171 = 109）。
    static let daysUntilDueDate = 109

    /// 例のデータを入れる。空の保存場所に使う。
    static func seed(into context: ModelContext, today: CalendarDay, now: Date) throws {
        let dueDate = today.adding(days: daysUntilDueDate)
        context.insert(PregnancyProfile(dueDateNumber: dueDate.number, showsGestationalAge: true, hasFinishedOnboarding: true))

        // 聞きたいこと（次の健診で聞く）。
        let questions: [(text: String, note: String, isStarred: Bool)] = [
            ("腰が痛いときに気をつけること", "夜、寝返りのときに痛む", true),
            ("里帰り出産の手続きはいつまでにすればよいか", "", false),
            ("鉄分のとり方", "サプリでもよいか", false),
            ("エコー写真をもらえるか", "", false),
        ]
        for (offset, question) in questions.enumerated() {
            context.insert(Question(
                text: question.text,
                note: question.note,
                isStarred: question.isStarred,
                sortOrder: offset,
                createdAt: now
            ))
        }

        // これまでの健診後メモ（2 週間前・6 週間前・10 週間前）。
        let memos: [(daysAgo: Int, body: String, items: [(question: String, note: String, answer: String)])] = [
            (
                14,
                "赤ちゃんは順調。体重の増え方はこのままでよい。\n次回は血液検査があるので、受診票を忘れずに。",
                [
                    ("夜に足がつることがある", "", "寝る前にふくらはぎを伸ばす。続くときは次回また相談"),
                    ("運動はどのくらいしてよいか", "", "散歩くらいなら毎日でよい。お腹が張ったら休む"),
                ]
            ),
            (
                42,
                "胎動はまだはっきりしなくても心配いらない。\n母親学級の申し込みを来週までにする。",
                [
                    ("足のむくみが気になる", "朝は平気", "夕方に強くなるのはよくある。足を高くして休む"),
                ]
            ),
            (
                70,
                "母子健康手帳の受診票を毎回持ってくる。",
                [
                    ("仕事はいつまで続けてよいか", "", "体調しだい。つらいときは早めに相談"),
                ]
            ),
        ]
        var newestMemoID: UUID?
        for memo in memos {
            let model = CheckupMemo(
                id: UUID(),
                visitDayNumber: today.adding(days: -memo.daysAgo).number,
                body: memo.body,
                dueDateNumberAtVisit: dueDate.number,
                createdAt: now
            )
            context.insert(model)
            if newestMemoID == nil {
                newestMemoID = model.id
            }
            for (offset, item) in memo.items.enumerated() {
                let memoItem = MemoItem(questionText: item.question, answer: item.answer, note: item.note, sortOrder: offset)
                context.insert(memoItem)
                memoItem.memo = model
            }
        }

        // 2 週間前のメモに、見本の絵を 2 枚付ける（段階 F3）。紹介動画で写真の機能を見せるため。
        // 本当の写真と同じ道筋（PhotoProcessing）で、大きい画像と小さい画像を作る。
        if let newestMemoID {
            for (offset, data) in [SampleImages.picture(), SampleImages.handout()].enumerated() {
                let photo = try PhotoProcessing.prepare(data)
                context.insert(MemoPhoto(
                    memoID: newestMemoID,
                    imageData: photo.imageData,
                    thumbnailData: photo.thumbnailData,
                    sortOrder: offset,
                    createdAt: now
                ))
            }
        }

        // 次の健診（2 週間後の 10:30、前日 21:00 のお知らせ）と持ち物（1 つだけチェック済み）。
        context.insert(NextCheckup(
            day: today.adding(days: 14),
            hour: 10,
            minute: 30,
            isReminderOn: true,
            reminderSlot: ReminderTimeRule.defaultSlot
        ))
        for (offset, name) in NoteService.initialBringItemNames.enumerated() {
            context.insert(BringItem(name: name, isChecked: offset == 0, sortOrder: offset))
        }

        try context.save()
    }
}

/// サンプルデータを表示している間の、お知らせの窓口。iPhone の通知には触れず、予約したことにだけする。
///
/// 本当のお知らせを消したり増やしたりしないため（6 章）。許可はあることにして、カードに「前日の 21:00 にお知らせ」と出す。
final class SampleReminderCenter: ReminderCenter {
    private var pending: [String] = []

    func authorizationStatus() async -> ReminderAuthorization {
        .authorized
    }

    func requestAuthorization() async -> Bool {
        true
    }

    func pendingIdentifiers() async -> [String] {
        pending
    }

    func schedule(_ reminder: PlannedReminder) async throws {
        pending.append(reminder.identifier)
    }

    func cancel(identifiers: [String]) {
        pending.removeAll { identifiers.contains($0) }
    }
}
