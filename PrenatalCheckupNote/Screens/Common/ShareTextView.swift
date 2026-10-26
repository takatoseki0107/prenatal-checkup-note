import SwiftUI

/// 「共有する文章」の画面（段階 D の決まり）。
///
/// 健康のことが入る文章なので、何を送るかを先に見せてから、［共有する］で iPhone の共有シートを開く。
/// 共有シートは SwiftUI の `ShareLink` で開く。印刷は要らないので、文章だけを渡す（ADR 0004 の追記）。
struct ShareTextView: View {
    let text: String

    var body: some View {
        List {
            Section {
                Text(text)
                    .font(.maru(.callout))
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            } footer: {
                Text("この文章を、メッセージやメモなどに送れます。写真は入りません。送る前に、中身を確かめてください。")
            }
        }
        .appBackground()
        .navigationTitle("共有する文章")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            ShareLink(item: text) {
                Label("共有する", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(AppColors.background)
        }
    }
}

/// 「次の健診」の聞きたいことの一覧を共有するシート。
struct ShareQuestionsSheet: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ShareTextView(text: text)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
        }
    }

    private var text: String {
        ShareText.questionList(
            nextCheckup: nextCheckupText,
            questions: store.questions.map {
                ShareText.Question(text: $0.text, note: $0.note, answer: $0.answer, isStarred: $0.isStarred)
            }
        )
    }

    /// 次の健診の日時。週数は「妊娠週数を表示する」がオンのときだけ付ける（`gestationalAgeText` が見る）。
    private var nextCheckupText: String? {
        guard let next = store.nextCheckup, let day = next.day else {
            return nil
        }
        let dateText = "\(day.displayText) \(next.hour):\(String(format: "%02d", next.minute))"
        if let ageText = store.gestationalAgeText(on: day) {
            return "\(dateText)（\(ageText)）"
        }
        return dateText
    }
}
