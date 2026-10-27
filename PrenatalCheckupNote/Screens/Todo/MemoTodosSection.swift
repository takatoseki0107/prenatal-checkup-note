import SwiftUI

/// 健診後メモの画面（書く・見る）に置く「やることに足す」のまとまり（要件定義 v0.4 の 5.10、R-107）。
///
/// 先生に言われた「次までにすること」を、メモの画面から移らずにやることに足せる。
/// このメモから足したやることを並べ、その下に「＋ やることに足す」を出す。シートを開くのは、置いた画面の側（`onAdd`）。
/// 触れる見本 `MemoToTodo.dc.html` で開発者と形を決めた。
struct MemoTodosSection: View {
    @Environment(NoteStore.self) private var store
    /// どのメモ（または書きかけ）の画面か。
    let memoID: UUID
    /// 「＋ やることに足す」を押したとき。
    let onAdd: () -> Void

    var body: some View {
        Section {
            ForEach(todos) { todo in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.isCompleted ? Color.accentColor : .secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(todo.title)
                            .strikethrough(todo.isCompleted)
                        Text(dueText(todo))
                            .font(.maru(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Button {
                onAdd()
            } label: {
                Label("やることに足す", systemImage: "plus")
            }
        } header: {
            Text("次までにすること")
        } footer: {
            Text("先生に言われた「次までにすること」を、やることに足せます。「やること」のタブに、どの健診で言われたかと一緒に出ます。")
        }
    }

    private var todos: [TodoItem] {
        store.todos(fromMemo: memoID)
    }

    /// 例：「11月23日（月）まで」「期限なし」「完了しました」。
    private func dueText(_ todo: TodoItem) -> String {
        if todo.isCompleted {
            return "完了しました"
        }
        guard let dueDay = todo.dueDay else {
            return "期限なし"
        }
        return "\(dueDay.displayText)まで"
    }
}
