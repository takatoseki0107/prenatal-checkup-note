import SwiftUI

/// アプリの色（段階 F の見た目。見た目案 v3 の空色）。
///
/// 色の値は `Assets.xcassets` に、ライトとダークの 2 つずつ置いている。
/// 強調の色（ボタン・スイッチ・丸・タブ）は `AccentColor` で、アプリ全体に自動で効く。
enum AppColors {
    /// 画面の背景。ライトはほんのり青い白、ダークは青みのある黒。
    static let background = Color("AppBackground")
    /// 次の健診のカードの空色。
    static let skyCard = Color("SkyCard")
}

extension View {
    /// 一覧（List）やフォーム（Form）の背景を、アプリの背景の色にする。
    ///
    /// 標準の灰色の背景を隠してから、空色系の背景を敷く。行の白い地はそのまま残る。
    func appBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(AppColors.background)
    }
}
