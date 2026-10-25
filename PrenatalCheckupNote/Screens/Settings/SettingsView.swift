import SwiftUI

/// 設定（要件定義 v0.4 の 4 章「シート」の設定）。右上の歯車から開く。
///
/// 出産予定日・「妊娠週数を表示する」・「出産予定日を消す」は B6 で足す。
/// 開発用ビルドでは、開発用の切り替えもここに置く（サンプルデータは段階 D）。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("出産予定日") {
                    Text("出産予定日と妊娠週数の設定は、このあと作ります。")
                        .foregroundStyle(.secondary)
                }
                #if DEBUG
                DeveloperSection()
                #endif
            }
            .navigationTitle("設定")
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
