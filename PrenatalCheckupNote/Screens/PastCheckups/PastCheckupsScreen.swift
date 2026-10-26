import SwiftUI

/// タブ 2「これまでの健診」（要件定義 v0.4 の 4 章）。
///
/// 健診後メモの一覧（新しい順）。行を押すと、見る・直す・削除するシートを開く（B5）。
/// 出産予定日があれば、各行に記録したときの予定日で計算した週数を出す（R-52）。
/// 一覧の上の検索の欄で、本文・聞いた質問・補足・先生の答えから探せる（段階 D1、決まりは `MemoSearch`）。
struct PastCheckupsScreen: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router
    /// 検索の欄に入れた文。
    @State private var query = ""

    var body: some View {
        List {
            if let results = searchResults {
                searchResultsSection(results)
            } else {
                memoListSection
            }
        }
        .navigationTitle("これまでの健診")
        .searchable(text: $query, prompt: "メモを探す（例：むくみ 足）")
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
            if store.pendingUndo != nil {
                UndoBar()
                    .background(.bar)
            }
        }
        .animation(.default, value: store.pendingUndo)
    }

    /// 検索した結果。検索していない（言葉が入っていない）ときは `nil`。
    private var searchResults: [MemoSearch.Result]? {
        let documents = store.memos.map { memo in
            MemoSearch.Document(
                id: memo.id,
                body: memo.body,
                items: memo.sortedItems.map { .init(question: $0.questionText, note: $0.note, answer: $0.answer) }
            )
        }
        return MemoSearch.search(query, in: documents)
    }

    /// 検索の結果。当たったメモの日付と、当たった所の前後の文。
    private func searchResultsSection(_ results: [MemoSearch.Result]) -> some View {
        Section {
            if results.isEmpty {
                Text("「\(query.trimmingCharacters(in: .whitespacesAndNewlines))」に当たるメモはありません")
                    .foregroundStyle(.secondary)
            }
            ForEach(results, id: \.id) { result in
                if let memo = store.memos.first(where: { $0.id == result.id }) {
                    Button {
                        router.sheet = .memo(memo.id)
                    } label: {
                        SearchResultRow(memo: memo, snippet: result.snippet)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            if !results.isEmpty {
                Text("\(results.count)件")
            }
        }
    }

    /// 検索していないときの、メモの一覧。
    private var memoListSection: some View {
        Section {
            if store.memos.isEmpty {
                Text("まだ健診後メモはありません。")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.memos) { memo in
                Button {
                    router.sheet = .memo(memo.id)
                } label: {
                    MemoRow(memo: memo, photoCount: store.photos(forMemo: memo.id).count, isAgeShown: store.showsGestationalAge)
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("健診が終わったら、「次の健診」の画面の「健診後メモを書く」から書きます（次の健診の日付を入れると出ます）。メモを押すと、見返したり直したりできます。")
        }
    }
}

/// 検索の結果の 1 行。「◯月◯日（◯）の健診」と、当たった所の前後の文（当たった言葉は太字）。
private struct SearchResultRow: View {
    let memo: CheckupMemo
    let snippet: MemoSearch.Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(memo.visitDay?.displayText ?? "日付なし")の健診")
                .font(.headline)
            Text(snippetText)
                .font(.subheadline)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// 抜き出しの文。どこから抜き出したか（「先生の答え：」など）を頭に付け、当たった言葉を太字にする。
    private var snippetText: AttributedString {
        var text = AttributedString()
        if let label = snippet.label {
            var prefix = AttributedString("\(label)：")
            prefix.foregroundColor = Color.secondary
            text += prefix
        }
        for piece in snippet.pieces {
            var part = AttributedString(piece.text)
            if piece.isMatch {
                part.inlinePresentationIntent = .stronglyEmphasized
                part.foregroundColor = Color.accentColor
            }
            text += part
        }
        return text
    }
}

/// 健診後メモの 1 行。「◯月◯日（◯）の健診」・本文の 1 行目・「この健診で聞いたこと n件」・写真の枚数（段階 E）。
private struct MemoRow: View {
    let memo: CheckupMemo
    let photoCount: Int
    /// 「妊娠週数を表示する」（R-53）。オフなら、過去のメモにも出さない。
    let isAgeShown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(memo.visitDay?.displayText ?? "日付なし")の健診")
                .font(.headline)
            if let ageText = GestationalAgeDisplay.text(for: memo.gestationalAgeAtVisit, isShown: isAgeShown) {
                Text(ageText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(preview)
                .font(.subheadline)
                .foregroundStyle(memo.body.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            HStack(spacing: 12) {
                Text("この健診で聞いたこと \(memo.items.count)件")
                if photoCount > 0 {
                    // 写真の印は、文字の中に入れて「写真 n枚」とくっつける。
                    Text("\(Image(systemName: "photo")) 写真 \(photoCount)枚")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // メモとメモの間の区切り線は、行の左はしから引く。
        // 指定しないと、行の中の文字の位置に合わせて引かれ、写真の印があると左が欠けた（E3 の画面の確認で見つかった）。
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    /// 本文の 1 行目。本文がなければ、そう書く。
    private var preview: String {
        let firstLine = memo.body.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init)
        return firstLine ?? "（先生の話のメモなし）"
    }
}
