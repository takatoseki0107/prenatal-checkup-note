import Foundation
import SwiftData

/// 面接や紹介動画で見せるための、例のデータ（要件定義 v0.4 の段階 D、6 章）。開発用ビルドの「サンプルデータを表示する」で使う。
///
/// 本当のデータとは別の保存場所（`AppDataStore.makeSampleContainer`）に入れる。本当のデータとお知らせには触れない。
/// 日付は今日から数えて作るので、いつ見せても「今日は妊娠 24 週 3 日、次の健診は 2 週間後」になる。
/// 2 週間前のメモには、コードで描いた見本の絵を 2 枚付ける（段階 F3、`SampleImages`）。本当の写真は使わない。
/// タスク（5.10）は、一覧のまとまり（期限なし・期限を過ぎた・今日・日付・次の健診の日）と、緑のチェック・完了したタスク・
/// 健診後メモから追加したタスクが一通り見えるように入れる（ToDo 4）。
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
        var memoIDs: [Int: UUID] = [:]
        for memo in memos {
            let model = CheckupMemo(
                id: UUID(),
                visitDayNumber: today.adding(days: -memo.daysAgo).number,
                body: memo.body,
                dueDateNumberAtVisit: dueDate.number,
                createdAt: now
            )
            context.insert(model)
            memoIDs[memo.daysAgo] = model.id
            for (offset, item) in memo.items.enumerated() {
                let memoItem = MemoItem(questionText: item.question, answer: item.answer, note: item.note, sortOrder: offset)
                context.insert(memoItem)
                memoItem.memo = model
            }
        }

        // 2 週間前のメモに、見本の絵を 2 枚付ける（段階 F3）。紹介動画で写真の機能を見せるため。
        // 本当の写真と同じ道筋（PhotoProcessing）で、大きい画像と小さい画像を作る。
        if let newestMemoID = memoIDs[14] {
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

        insertTodos(into: context, today: today, now: now, memoIDs: memoIDs)

        try context.save()
    }

    /// タスク（5.10、ToDo 4）。紹介動画で、一覧のまとまり・緑のチェック・完了・健診後メモからの追加を見せるため。
    ///
    /// - 期限を過ぎた 1 件と今日の 2 件で、タブの数は 3。
    /// - 次の健診（2 週間後）までのものは 5 件（健診予定のカードに出る）。そのうち期限を過ぎたものが 1 件。
    /// - 2 週間前のメモから追加した「受診票に記入する」は、期限が次の健診の日。6 週間前のメモから追加した「母親学級の申し込み」は完了済み。
    private static func insertTodos(into context: ModelContext, today: CalendarDay, now: Date, memoIDs: [Int: UUID]) {
        let nextCheckupDay = today.adding(days: 14)
        let items: [TodoItem] = [
            TodoItem(
                title: "里帰り先の産院に分娩予約の電話をする",
                note: "平日 14 時〜16 時",
                dueDay: today.adding(days: -2),
                isStarred: true,
                createdAt: now.addingTimeInterval(-3 * 86_400)
            ),
            TodoItem(title: "産休の届けを会社に出す", dueDay: today, createdAt: now.addingTimeInterval(-60)),
            TodoItem(title: "母子手帳ケースを買う", dueDay: today, isChecked: true, createdAt: now.addingTimeInterval(-50)),
            TodoItem(title: "ベビーベッドのレンタルを調べる", dueDay: today.adding(days: 7), createdAt: now.addingTimeInterval(-40)),
            TodoItem(
                title: "血液検査の受診票に記入する",
                note: "健診の前の日までに",
                dueDay: nextCheckupDay,
                originVisitDay: today.adding(days: -14),
                originMemoID: memoIDs[14],
                createdAt: now.addingTimeInterval(-14 * 86_400)
            ),
            TodoItem(title: "入院の準備のリストを作る", createdAt: now.addingTimeInterval(-30)),
            TodoItem(
                title: "母親学級の申し込み",
                dueDay: today.adding(days: -35),
                completedAt: now.addingTimeInterval(-36 * 86_400),
                originVisitDay: today.adding(days: -42),
                originMemoID: memoIDs[42],
                createdAt: now.addingTimeInterval(-42 * 86_400)
            ),
        ]
        for item in items {
            context.insert(item)
        }
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
