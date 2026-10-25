import SwiftUI

/// タブ 1「次の健診」（要件定義 v0.4 の 4 章）。
///
/// 「聞きたいこと」の一覧と「＋ 質問を追加」。行を押すと質問のシートを開く（B2）。
/// 次の健診のカードは B4、「健診後メモを書く」は B3、上の帯の妊娠週数は B6 で足す。
struct NextCheckupScreen: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            Section {
                if store.questions.isEmpty {
                    Text("聞きたいことはまだありません。思いついたら「＋ 質問を追加」で書き留めておきましょう。")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.questions) { question in
                    QuestionRow(question: question)
                }
                // 長押しして指で動かすと並べ替わる（R-04）。
                .onMove { source, destination in
                    store.perform { try $0.moveQuestions(fromOffsets: source, toOffset: destination) }
                }
                // 左にスワイプすると削除。確認は出さず、元に戻すの帯を出す（R-06）。
                .onDelete { offsets in
                    deleteQuestions(at: offsets)
                }
            } header: {
                Text("聞きたいこと（\(store.questions.count)件）")
            } footer: {
                if !store.questions.isEmpty {
                    Text("丸を押すと「聞いた」になります。星は大事な質問の印です。文を押すと直せます。長押しで並べ替え、左にスワイプで削除できます。")
                }
            }
        }
        .navigationTitle("次の健診")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.sheet = .settings
                } label: {
                    Label("設定", systemImage: "gearshape")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                UndoBar()
                Button {
                    router.sheet = .addQuestion
                } label: {
                    Label("質問を追加", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.bar)
            .animation(.default, value: store.pendingUndo)
        }
    }

    private func deleteQuestions(at offsets: IndexSet) {
        let ids = offsets.map { store.questions[$0].id }
        // 1 件ずつ消す。元に戻せるのは、最後に消した 1 件（R-60）。スワイプでは 1 件ずつしか消えない。
        for id in ids {
            store.perform { try $0.deleteQuestion(id: id) }
        }
    }
}

/// 聞きたいことの 1 行。丸（聞いた）・本文・補足・先生の答え・星。文のところを押すと、質問のシートを開く。
private struct QuestionRow: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router
    let question: Question

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.perform { try $0.setAsked(!question.isAsked, questionID: question.id) }
            } label: {
                Image(systemName: question.isAsked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(question.isAsked ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(question.isAsked ? "聞いた" : "聞く前")
            .accessibilityHint(question.isAsked ? "押すと聞く前に戻します" : "押すと聞いたにします")

            Button {
                router.sheet = .editQuestion(question.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    // 丸を付けても、その場に残して薄く出す（R-02）。
                    Text(question.text)
                        .foregroundStyle(question.isAsked ? .secondary : .primary)
                    if !question.note.isEmpty {
                        Text(question.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !question.answer.isEmpty {
                        Text("先生の答え：\(question.answer)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // 文のない右側の余白を押しても開くようにする。
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("押すと、質問を直す画面を開きます")

            // 星は印だけ。付けても並びは変えない（R-03）。
            Button {
                store.perform { try $0.setStarred(!question.isStarred, questionID: question.id) }
            } label: {
                Image(systemName: question.isStarred ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(question.isStarred ? Color.orange : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(question.isStarred ? "星あり" : "星なし")
            .accessibilityHint(question.isStarred ? "押すと星を外します" : "押すと星を付けます")
        }
    }
}
