import SwiftUI

/// タブ 1「次の健診」（要件定義 v0.4 の 4 章）。
///
/// いちばん上に次の健診のカード、その下に「聞きたいこと」の一覧、画面の下に「＋ 質問を追加」「健診後メモを書く」。
/// 行を押すと質問のシートを開く。出産予定日があれば、いちばん上に今日の妊娠週数を出す（R-51）。
/// カードのお知らせのスイッチは段階 C で足す。
struct NextCheckupScreen: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            if let todayAgeText = store.gestationalAgeText(on: CalendarDay(.now)) {
                Section {
                    Text("今日　\(todayAgeText)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.background))
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }

            NextCheckupCard()

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
                // 「健診後メモを書く」を出さないときは、「＋ 質問を追加」を横いっぱいにする（R-20）。
                HStack(spacing: 12) {
                    Button {
                        router.sheet = .addQuestion
                    } label: {
                        Label("質問を追加", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    if let title = memoEntry.title {
                        Button {
                            startMemo()
                        } label: {
                            Text(title)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.bar)
            .animation(.default, value: store.pendingUndo)
        }
    }

    /// 健診後メモの入口（R-20）。次の健診の日付・丸を付けた質問・入力途中のメモのどれかがあるときだけ出す。
    private var memoEntry: MemoSheetRules.Entry {
        MemoSheetRules.entry(
            hasNextCheckup: store.nextCheckup != nil,
            hasAskedQuestion: store.questions.contains(where: \.isAsked),
            hasDraft: store.memoDraft != nil
        )
    }

    /// 健診後メモを書き始める。入力途中のメモを作ってから（あれば、それを使って）シートを開く（R-10、R-70）。
    private func startMemo() {
        let started = store.perform(saveFailureMessage: "健診後メモを書き始められませんでした。もう一度試してください。") {
            try $0.startMemoDraft(today: CalendarDay(.now), now: .now)
        }
        if started != nil {
            router.sheet = .writeMemo
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

/// 次の健診のカード（要件定義 v0.4 の 4 章）。
///
/// 日付が入っているときは、日時と「変更」、持ち物 n / m と「見る」。
/// 日付がないときは、点線の「＋ 次の健診の日付を入れる」と、その下に案内（R-20 の入口に日付が要るため）。
private struct NextCheckupCard: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let next = store.nextCheckup, let day = next.day {
            Section {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("日時　\(day.displayText) \(next.hour):\(String(format: "%02d", next.minute))")
                            .font(.headline)
                        if let ageText = store.gestationalAgeText(on: day) {
                            Text("\(ageText)の健診")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("変更") {
                        router.sheet = .nextCheckup
                    }
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                }
                HStack(spacing: 8) {
                    Text("持ち物　\(checkedItemCount) / \(store.bringItems.count)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("見る") {
                        router.sheet = .bringItems
                    }
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                }
            }
        } else {
            Section {
                Button {
                    router.sheet = .nextCheckup
                } label: {
                    Text("＋ 次の健診の日付を入れる")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("健診の日付を入れると、健診後メモを書けます。")
            }
        }
    }

    private var checkedItemCount: Int {
        store.bringItems.filter(\.isChecked).count
    }
}
