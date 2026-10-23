import SwiftUI

/// 未割り当ての質問から、健診で聞くものを選ぶシート。複数を選べる。
///
/// 選んだ質問は、一覧に並んでいる順番のまま、健診の最後に加える。
struct UnassignedQuestionPicker: View {
    let questions: [PrototypeQuestion]
    /// 「追加」を押したときに呼ぶ。選んだ質問のIDを、一覧の順番で渡す。
    let onAssign: ([UUID]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(questions) { question in
                let isSelected = selectedIDs.contains(question.id)
                Button {
                    toggle(question.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .accessibilityHidden(true)
                        Text(question.text)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            .navigationTitle("未割り当てから選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        onAssign(questions.map(\.id).filter { selectedIDs.contains($0) })
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

#Preview {
    UnassignedQuestionPicker(questions: PrototypeStore().data.unassignedQuestions) { _ in }
}
