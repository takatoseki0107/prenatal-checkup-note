import Foundation

/// 「使い方」のシート（要件定義 5.12、キャンバスの見本 `HelpSheetNext.dc.html`・`HelpSheetTrouble.dc.html`）に出す文。
///
/// 文はアプリの中に持ち、通信はしない（R-121）。画面の言葉を変えたら、ここの文も合わせて直す。
/// 健診予定と困ったときの文は、見本で開発者と決めた（ボタンの名前は、いまの画面の言葉に合わせた）。タスクと健診の記録は、同じ形で書いた。
nonisolated enum HelpTopic: CaseIterable, Hashable, Sendable {
    case next
    case todo
    case past
    case trouble

    /// 上の切り替えのボタンの文。
    var title: String {
        switch self {
        case .next: "健診予定"
        case .todo: "タスク"
        case .past: "健診の記録"
        case .trouble: "困ったとき"
        }
    }
}

/// 番号つきの手順の 1 つ。
nonisolated struct HelpStep: Equatable, Sendable {
    let title: String
    let body: String
}

/// 困ったときの、問いと答えの 1 組。
nonisolated struct HelpQuestion: Equatable, Sendable {
    let question: String
    let answer: String
}

nonisolated enum HelpContent {
    /// タブの使い方の、番号つきの手順（R-118）。困ったときは手順ではなく問いと答え（`questions`）なので、空。
    static func steps(for topic: HelpTopic) -> [HelpStep] {
        switch topic {
        case .next:
            [
                HelpStep(title: "質問を書き留める", body: "下の「＋ 質問を追加」から。大事な質問には ★。長押しで並べ替えられます。"),
                HelpStep(title: "次の健診を入れる", body: "上のカードの「日付を入れる」（入っていれば「変更」）から。持ち物と、前日の夜のお知らせもここで。"),
                HelpStep(title: "診察中は丸を付ける", body: "一覧を見ながら、聞いた質問の ○ を押します。質問を押すと、先生の答えを書けます。"),
                HelpStep(title: "診察のあとにメモを書く", body: "「健診後メモを書く」から。丸を付けた質問がメモに移り、「健診の記録」に残ります。"),
            ]
        case .todo:
            [
                HelpStep(title: "タスクを追加する", body: "下の「＋ タスクを追加」から。期限は「今日」「明日」「次の健診まで」などのボタンで選べます。"),
                HelpStep(title: "健診後メモから追加する", body: "健診後メモの画面の「＋ タスクを追加」から。どの健診で言われたかが残ります。"),
                HelpStep(title: "終わったらチェックする", body: "左の ○ を押すと緑のチェックが付きます。下の「チェックした n 件を完了にする」で「完了したタスク」に移ります。"),
                HelpStep(title: "直す・消す", body: "右の「直す」から、文や期限を直せます。左にスワイプしても消せます。"),
            ]
        case .past:
            [
                HelpStep(title: "メモを見返す", body: "一覧のメモを押すと、先生の答えや写真を見られます。"),
                HelpStep(title: "ワードで探す", body: "上の「メモを探す」に言葉を入れると、本文・質問・先生の答えから探します。空白で区切ると、すべてを含むメモを探します。"),
                HelpStep(title: "写真を大きく見る", body: "写真を押すと大きく出ます。2 本の指で広げるか、2 回たたくと拡大できます。"),
                HelpStep(title: "直す・共有する", body: "メモを開いて「編集」から直せます。下の「この健診後メモを共有する」で、文章として送れます。"),
            ]
        case .trouble:
            []
        }
    }

    /// 手順の下のひとことのコツ。
    static func tip(for topic: HelpTopic) -> String? {
        switch topic {
        case .next: "間違えて消しても、下に出る「元に戻す」で戻せます。"
        case .todo: "健診予定のカードの「タスク」を押すと、次の健診までのものだけを見られます。"
        case .past: "写真は 1 つのメモに 5 枚まで付けられます。"
        case .trouble: nil
        }
    }

    /// 困ったときの問いと答え（R-119）。
    static let questions: [HelpQuestion] = [
        HelpQuestion(
            question: "お知らせが届かない",
            answer: "iPhone の設定 →「通知」→「妊婦健診ノート」で、通知が許可されているか確かめてください。お知らせの時刻を過ぎた予定には、お知らせを設定できません。"
        ),
        HelpQuestion(
            question: "記録はどこに保存される？",
            answer: "この iPhone の中だけです。ほかの人や外のサービスには送りません。アプリを消すと、記録も消えます。"
        ),
        HelpQuestion(
            question: "間違えて消してしまった",
            answer: "消した直後に下に出る「元に戻す」を押すと戻せます。帯が消えたあとは戻せません。"
        ),
        HelpQuestion(
            question: "書きかけのメモを閉じてしまった",
            answer: "消えていません。健診予定の「入力途中のメモを続ける」から続きを書けます。"
        ),
        HelpQuestion(
            question: "妊娠週数を出したくない・直したい",
            answer: "右上の歯車の設定で、「妊娠週数を表示する」をオフにするか、出産予定日を直せます。"
        ),
    ]
}
