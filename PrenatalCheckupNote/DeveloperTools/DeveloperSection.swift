#if DEBUG
import SwiftUI

/// 設定の中の、開発用の欄。開発用ビルドだけに含め、リリースビルドには入れない。
///
/// 保存の失敗の切り替えと、実機での動作確認への入口をまとめる。サンプルデータは段階 D でここに置く。
/// 段階 A の確認用の画面は、本番の健診後メモのシートができた B3 で外した。
struct DeveloperSection: View {
    var body: some View {
        @Bindable var settings = DeveloperSettings.shared

        Section {
            Toggle("保存を失敗させる", isOn: $settings.failsSaving)
            NavigationLink("実機での動作確認") {
                DeviceCheckView()
            }
        } header: {
            Text("開発用")
        } footer: {
            Text("「保存を失敗させる」をオンにすると、保存がすべて失敗します。失敗しても、入力した内容や保存済みのデータが消えないことを確かめるために使います。アプリを終了すると、オフに戻ります。")
        }
    }
}
#endif
