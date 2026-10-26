import SwiftUI
import UIKit

/// アプリの色（段階 F の見た目。見た目案 v3 の空色に、やわらかいピンクと星の黄色を少し足す）。
///
/// 色の値は `Assets.xcassets` に、ライトとダークの 2 つずつ置いている。
/// 強調の色（ボタン・スイッチ・丸・タブ）は `AccentColor` で、アプリ全体に自動で効く。
enum AppColors {
    /// 画面の背景。ライトはほんのり青い白、ダークは iOS 標準と同じ黒（行の灰色の地となじむように）。
    static let background = Color("AppBackground")
    /// 健診予定のカードの空色。
    static let skyCard = Color("SkyCard")
    /// やわらかいピンク。今日の週数のハートに使う。
    static let pink = Color("AccentPink")
    /// 星（大事な質問）の黄色。
    static let star = Color("StarYellow")
}

/// アプリの字体（段階 F）。iPhone に最初から入っている丸い字体「ヒラギノ丸ゴ」を使う。
///
/// 字体のファイルをアプリに入れなくてよい。iPhone の文字の大きさの設定に合わせて、大きさも変わる（`relativeTo`）。
/// 見つからないときは、iOS が標準の字体で出すので、文字が消えることはない。
enum AppFonts {
    /// ヒラギノ丸ゴの名前。太さは 1 つ（W4）だけ。
    static let maruName = "HiraMaruProN-W4"

    /// iPhone の標準の文字の大きさ（設定が「標準」のとき）。
    static func baseSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }

    /// 画面の上の題名（「健診予定」など）も丸い字体にする。題名は UIKit が出しているので、UIKit の側で決める。
    static func applyToNavigationBars() {
        guard let base = UIFont(name: maruName, size: 17) else {
            return
        }
        let largeTitle = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: base.withSize(baseSize(.largeTitle)))
        let inlineTitle = UIFontMetrics(forTextStyle: .headline).scaledFont(for: base.withSize(baseSize(.headline)))
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitle]
        UINavigationBar.appearance().titleTextAttributes = [.font: inlineTitle]
    }
}

extension Font {
    /// 丸い字体で、指定した文字の役割（見出し・注釈など）の大きさにする。例：`.font(.maru(.headline))`。
    static func maru(_ style: Font.TextStyle) -> Font {
        .custom(AppFonts.maruName, size: AppFonts.baseSize(style), relativeTo: style)
    }
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
