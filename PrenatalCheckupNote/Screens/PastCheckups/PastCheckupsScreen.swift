import SwiftUI

/// タブ 2「これまでの健診」（要件定義 v0.4 の 4 章）。
///
/// 健診後メモの一覧（新しい順）。行を押すと、見る・直す・削除するシートを開く（B5）。
/// 週数は B6、検索は段階 D で足す。
struct PastCheckupsScreen: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            Section {
                if store.memos.isEmpty {
                    Text("まだ健診後メモはありません。")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.memos) { memo in
                    Button {
                        router.sheet = .memo(memo.id)
                    } label: {
                        MemoRow(memo: memo)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("健診が終わったら、「次の健診」の画面の「健診後メモを書く」から書きます（次の健診の日付を入れると出ます）。メモを押すと、見返したり直したりできます。")
            }
        }
        .navigationTitle("これまでの健診")
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
}

/// 健診後メモの 1 行。「◯月◯日（◯）の健診」・本文の 1 行目・「この健診で聞いたこと n件」。
private struct MemoRow: View {
    let memo: CheckupMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(memo.visitDay?.displayText ?? "日付なし")の健診")
                .font(.headline)
            Text(preview)
                .font(.subheadline)
                .foregroundStyle(memo.body.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            Text("この健診で聞いたこと \(memo.items.count)件")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// 本文の 1 行目。本文がなければ、そう書く。
    private var preview: String {
        let firstLine = memo.body.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init)
        return firstLine ?? "（先生の話のメモなし）"
    }
}
