import Foundation

/// 「ようこそ」の画面（はじめにの 1 枚目、要件定義 5.11 の R-112）で紹介する、3 つのタブでできること。
///
/// 見出しと箇条書きの文は、キャンバスの見本（`OnboardC1.dc.html`）で開発者と決めた。
/// 使い方の画面（5.12 の R-120）で、同じ「ようこそ」をもう一度見せるときにも使う。
nonisolated struct WelcomeFeature: Equatable, Sendable {
    /// どのタブか。印と色は、各タブの見出し（`ScreenHeader`）と同じにする。
    nonisolated enum Tab: Equatable, Sendable {
        case next
        case todo
        case past
    }

    let tab: Tab
    let title: String
    let bullets: [String]

    /// 画面に出す順（タブの並びと同じ）。
    static let all: [WelcomeFeature] = [
        WelcomeFeature(
            tab: .next,
            title: "健診予定",
            bullets: [
                "思いついた質問を、すぐ書き留める",
                "診察中は一覧を見て、聞いたものに丸を付ける",
                // 最初は「前日の夜に、持ち物と質問のお知らせが届く」だったが、「質問のお知らせ」がわかりにくい（開発者の指摘）。
                // 次の「健診の前日の夜に、忘れないようお知らせが届く」は 2 行に折り返したので、短くした。
                "前日の夜に、健診のお知らせが届く",
            ]
        ),
        WelcomeFeature(
            tab: .todo,
            title: "タスク",
            bullets: [
                "先生に言われた申請や病院への連絡を、忘れないようにメモできる",
                "期限を決めて、日にちごとにまとめて見られる",
            ]
        ),
        WelcomeFeature(
            tab: .past,
            title: "健診の記録",
            bullets: [
                "先生の答えやエコー写真を、健診ごとに残す",
                "ワードで検索して、簡単に見返せる",
            ]
        ),
    ]
}
