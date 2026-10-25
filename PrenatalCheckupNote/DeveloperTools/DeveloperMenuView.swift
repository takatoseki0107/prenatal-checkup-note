#if DEBUG
import SwiftUI

/// 開発用のメニュー。実機での動作確認への入口をまとめる。
///
/// 開発用ビルドだけに含め、リリースビルドには入れない。
/// 段階 A 以降で、保存の失敗の切り替えやサンプルデータもここに置く（要件定義 v0.4 の 7 章 S-08）。
struct DeveloperMenuView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
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

#Preview {
    DeveloperMenuView()
}
#endif
