#if DEBUG
import SwiftUI

/// 開発用のメニュー。段階1の状態の切り替え、保存の失敗の切り替え、実機での動作確認への入口をまとめる。
///
/// 開発用ビルドだけに含め、リリースビルドには入れない（要件定義 17章「段階1の状態切り替え」）。
struct DeveloperMenuView: View {
    /// 状態を選んだときに呼ぶ。呼び出し側で、データの作り直しと最初の画面への移動を行う。
    let onSelectScenario: (PrototypeScenario) -> Void

    @Environment(PrototypeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            List {
                Section {
                    ForEach(PrototypeScenario.allCases) { scenario in
                        Button {
                            onSelectScenario(scenario)
                            dismiss()
                        } label: {
                            ScenarioRow(scenario: scenario, isSelected: scenario == store.scenario)
                        }
                    }
                } header: {
                    Text("状態の切り替え")
                } footer: {
                    Text("選ぶと、データを標準データから作り直し、その状態の最初の画面を開きます。")
                }

                Section {
                    Toggle("健診の完了の保存を失敗させる", isOn: $store.failures.completionSave)
                    Toggle("メモの保存を失敗させる", isOn: $store.failures.memoSave)
                } header: {
                    Text("保存の失敗")
                } footer: {
                    Text("再試行が成功する流れを見るときは、オフにしてから再試行します。状態を選び直すと初期値に戻ります。")
                }

                Section("そのほか") {
                    NavigationLink("実機での動作確認") {
                        DeviceCheckView()
                    }
                }
            }
            .navigationTitle("開発用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 状態の切り替えの1行。
private struct ScenarioRow: View {
    let scenario: PrototypeScenario
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.title)
                    .foregroundStyle(.primary)
                Text(scenario.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    DeveloperMenuView { _ in }
        .environment(PrototypeStore())
}
#endif
