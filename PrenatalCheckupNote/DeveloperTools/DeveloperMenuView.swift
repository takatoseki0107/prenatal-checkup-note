#if DEBUG
import SwiftUI

/// 開発用のメニュー。保存の失敗の切り替えと、実機での動作確認への入口をまとめる。
///
/// 開発用ビルドだけに含め、リリースビルドには入れない。サンプルデータは段階 D でここに置く。
struct DeveloperMenuView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = DeveloperSettings.shared

        NavigationStack {
            List {
                Section {
                    Toggle("保存を失敗させる", isOn: $settings.failsSaving)
                } header: {
                    Text("保存の失敗")
                } footer: {
                    Text("オンにすると、保存がすべて失敗します。失敗しても、入力した内容や保存済みのデータが消えないことを確かめるために使います。アプリを終了すると、オフに戻ります。")
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

#Preview {
    DeveloperMenuView()
}
#endif
