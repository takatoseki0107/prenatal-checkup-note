import SwiftUI

/// 持ち物のシート（要件定義 v0.4 の 4 章「持ち物」、R-34）。次の健診のカードの「見る」から開く。
///
/// チェックを付ける・外す、品目を足す・外す（元に戻せる）。品目は次の健診でも使うので残り、
/// 健診後メモを保存すると、チェックだけが外れる（R-15）。
struct BringItemsSheet: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newItemName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.bringItems.isEmpty {
                        Text("持ち物はありません。下の欄から足せます。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.bringItems) { item in
                        BringItemRow(item: item)
                    }
                } footer: {
                    Text("持ち物の品目は、次の健診でも使えるように残ります。健診後メモを保存すると、チェックだけが外れます。")
                }

                Section("持ち物を足す") {
                    HStack(spacing: 12) {
                        TextField("例：お薬手帳", text: $newItemName)
                            .submitLabel(.done)
                            .onSubmit(addItem)
                        Button("追加") {
                            addItem()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(InputText.normalized(newItemName) == nil)
                    }
                }
            }
            .navigationTitle("持ち物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            // 品目を外したときの元に戻すの帯は、シートの上にも出す（後ろの画面の帯はシートに隠れるため）。
            .safeAreaInset(edge: .bottom) {
                if store.pendingUndo != nil {
                    UndoBar()
                        .background(.bar)
                }
            }
            .animation(.default, value: store.pendingUndo)
        }
        // シートの上で起きた失敗は、シートの上で知らせる（ADR 0009）。
        .noteErrorAlert(store)
    }

    private func addItem() {
        let name = newItemName
        guard InputText.normalized(name) != nil else {
            return
        }
        if store.perform({ try $0.addBringItem(name: name) }) != nil {
            newItemName = ""
        }
    }
}

/// 持ち物の 1 行。押すとチェックが付く・外れる。右の × で品目を外す。
private struct BringItemRow: View {
    @Environment(NoteStore.self) private var store
    let item: BringItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.perform { try $0.setBringItemChecked(!item.isChecked, itemID: item.id) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundStyle(item.isChecked ? Color.accentColor : .secondary)
                    Text(item.name)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(item.isChecked ? "チェックあり" : "チェックなし")

            Button {
                store.perform { try $0.removeBringItem(id: item.id) }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("「\(item.name)」を持ち物から外す")
        }
    }
}
