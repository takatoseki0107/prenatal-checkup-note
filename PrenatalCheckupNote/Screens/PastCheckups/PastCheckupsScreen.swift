import SwiftUI

/// タブ 2「これまでの健診」（要件定義 v0.4 の 4 章）。
///
/// B1 では、健診後メモの一覧（新しい順）を出すだけ。見る画面・編集・削除は B5、検索は段階 D で足す。
struct PastCheckupsScreen: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            if store.memos.isEmpty {
                Text("まだ健診後メモはありません。健診のあとに「次の健診」で書くと、ここに並びます。")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.memos) { memo in
                MemoRow(memo: memo)
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

/// 健診後メモの 1 行。「◯月◯日（◯）の健診」・本文の頭・「この健診で聞いたこと n 件」。
private struct MemoRow: View {
    let memo: CheckupMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(memo.visitDay?.displayText ?? "日付なし")の健診")
                .font(.headline)
            if !memo.body.isEmpty {
                Text(memo.body)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            if !memo.sortedItems.isEmpty {
                Text("この健診で聞いたこと \(memo.sortedItems.count) 件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
