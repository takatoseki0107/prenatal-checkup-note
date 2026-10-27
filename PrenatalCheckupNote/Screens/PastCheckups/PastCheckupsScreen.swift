import SwiftUI

/// タブ 2「健診の記録」（要件定義 v0.4 の 4 章。段階 F で「これまでの健診」から名前を変えた）。
///
/// 健診後メモの一覧（新しい順）。行を押すと、見る・直す・削除するシートを開く（B5）。
/// 出産予定日があれば、各行に記録したときの予定日で計算した週数を出す（R-52）。
/// 一覧の上の検索の欄で、本文・聞いた質問・補足・先生の答えから探せる（段階 D1、決まりは `MemoSearch`）。
struct PastCheckupsScreen: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router
    /// 検索の欄に入れた文。
    @State private var query = ""
    /// 見出しが隠れて、上の帯に題名を出しているか。
    @State private var isShowingInlineTitle = false

    var body: some View {
        List {
            Section {
                ScreenHeader(kind: .past, title: "健診の記録", subtitle: ScreenHeaderText.past(memoCount: store.memos.count))
            }
            .listSectionSpacing(.compact)

            if let results = searchResults {
                searchResultsSection(results)
            } else {
                memoListSection
            }
        }
        // メモ 1 件ずつを、間を空けた丸いカードにする（段階 F）。
        .listRowSpacing(10)
        .appBackground()
        .onScrolledPastHeader { isShowingInlineTitle = $0 }
        .screenHeaderTitle("健診の記録", isShown: isShowingInlineTitle)
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
                    .background(AppColors.background)
                    // 下の帯は、文字サイズ最大でも画面の多くを占めないよう、大きさに上限を付ける（段階 F2）。
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
                    .listRowSeparator(.hidden)
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
                .listRowSeparator(.hidden)
            }
        } footer: {
            Text("健診が終わったら、「健診予定」の画面の「健診後メモを書く」から書きます（健診の日付を入れると出ます）。メモを押すと、見返したり直したりできます。")
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
                .font(.maru(.headline))
            Text(snippetText)
                .font(.maru(.subheadline))
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
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(memo.visitDay?.displayText ?? "日付なし")の健診")
                .font(.maru(.headline))
            if let ageText = GestationalAgeDisplay.text(for: memo.gestationalAgeAtVisit, isShown: isAgeShown) {
                Text(ageText)
                    .font(.maru(.caption))
                    .foregroundStyle(.secondary)
            }
            Text(preview)
                .font(.maru(.subheadline))
                .foregroundStyle(memo.body.isEmpty ? .secondary : .primary)
                // 文字サイズがとても大きいときは 1 行に数文字しか入らないので、2 行まで見せる（段階 F2）。
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            detailLayout {
                Text("この健診で聞いたこと \(memo.items.count)件")
                    // 一覧の中では 1 行に収めようとして「この健診で聞い…」と切れたので、折り返すようにする（段階 F2）。
                    .fixedSize(horizontal: false, vertical: true)
                if photoCount > 0 {
                    // 写真の印は、文字の中に入れて「写真 n枚」とくっつける。
                    Text("\(Image(systemName: "photo")) 写真 \(photoCount)枚")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.maru(.caption))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // メモは 1 件ずつのカードにしたので、区切り線は使わない（段階 F）。
        // 以前は区切り線を行の左はしから引く直しをしていた（E3 の画面の確認で、写真の印があると左が欠けたため）。
    }

    /// 「聞いたこと」と「写真」の並べ方。文字サイズがとても大きいときは、横に並べず縦に積む（段階 F2）。
    private var detailLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    /// 本文の 1 行目。本文がなければ、そう書く。
    private var preview: String {
        let firstLine = memo.body.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init)
        return firstLine ?? "（先生の話のメモなし）"
    }
}
