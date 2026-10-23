import Foundation

/// 共有・印刷する質問リストの文章を作る。要件定義 5章 F-16。
///
/// 健診ごとの質問リストと健診メモを、上から聞く順に番号を付けて並べる。
/// 日時の表示は呼び出し側で作って渡す。表示の形式（言語や時刻帯）に左右されずにテストできるようにするため。
nonisolated enum QuestionListShareText {
    /// - Parameters:
    ///   - dateText: 健診の日時の表示。例：「11月5日(木) 10:30」。
    ///   - questions: 質問文。上にあるほど先に聞く。
    ///   - appointmentMemo: 健診メモ。空なら含めない。
    static func make(dateText: String, questions: [String], appointmentMemo: String) -> String {
        var lines = ["\(dateText) の健診で聞くこと", ""]

        if questions.isEmpty {
            lines.append("（聞くことはまだありません）")
        } else {
            for (offset, question) in questions.enumerated() {
                lines.append("\(offset + 1). \(question)")
            }
        }

        let memo = appointmentMemo.trimmingCharacters(in: .whitespacesAndNewlines)
        if !memo.isEmpty {
            lines += ["", "健診メモ", memo]
        }

        return lines.joined(separator: "\n")
    }
}
