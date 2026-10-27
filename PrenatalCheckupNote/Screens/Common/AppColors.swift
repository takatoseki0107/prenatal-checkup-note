import SwiftUI
import UIKit

/// アプリの色（段階 F の見た目。見た目案 v3 の空色に、やわらかいピンクと星の黄色を少し足す）。
///
/// 色の値は `Assets.xcassets` に、ライトとダークの 2 つずつ置いている。
/// 強調の色（ボタン・スイッチ・丸・タブ）は `AccentColor` で、アプリ全体に自動で効く。
enum AppColors {
    /// 画面の背景。ライトはほんのり青い白、ダークは明るめの青灰色（#2A3850）。
    /// ダークは最初、iOS 標準と同じ真っ黒だったが、暗すぎて色が浮いて見えた（開発者の指摘）。
    /// 見本で 4 つの明るさを比べ、開発者がいちばん明るい青灰色を選んだ。
    static let background = Color("AppBackground")
    /// 一覧やフォームの行（カード）の地の色。ライトは白、ダークは背景より少し明るい青灰色。
    /// iOS 標準の行の色（灰色）は紺の背景と合わないので、すべての一覧とフォームの行にこの色を付ける。
    static let card = Color("CardBackground")
    /// 強調の色（`AccentColor`）で塗ったボタンの上の文字の色。ライトは白、ダークは濃い紺。
    /// ダークの強調の色は、明るい背景の上でも読めるよう明るい青（#86BDF0）にしたので、その上の文字は白では読みにくい。
    static let onAccent = Color("OnAccent")
    /// 健診予定のカードの空色。
    static let skyCard = Color("SkyCard")
    /// やわらかいピンク。今日の週数のハートに使う。
    static let pink = Color("AccentPink")
    /// 星（大事な質問）の黄色。
    static let star = Color("StarYellow")
    /// やることの緑のチェックと「完了にする」のボタン（5.10、R-104）。白い文字が読める濃さの緑にしている。
    static let check = Color("CheckGreen")
    /// 各タブの見出し（`ScreenHeader`）の色。健診予定はピンク、やることは黄色、健診の記録は空色。
    /// ダークでは、暗く沈んで見えないよう、少し明るさを残した深い色にしている（開発者の希望）。
    /// 印の後ろの四角。
    static let headerTintPink = Color("HeaderTintPink")
    static let headerTintYellow = Color("HeaderTintYellow")
    static let headerTintSky = Color("HeaderTintSky")
    /// 題名の下に敷く、蛍光ペンのような色。
    static let headerMarkerPink = Color("HeaderMarkerPink")
    static let headerMarkerYellow = Color("HeaderMarkerYellow")
    static let headerMarkerSky = Color("HeaderMarkerSky")
    /// 印の色。黄色と空色の四角の上でも見えるよう、ライトでは濃い色にしている。
    static let headerIconYellow = Color("HeaderIconYellow")
    static let headerIconSky = Color("HeaderIconSky")
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

    /// 画面の上の題名（「健診予定」など）とタブの文字も丸い字体にする。どちらも UIKit が出しているので、UIKit の側で決める。
    ///
    /// UIKit の準備ができてから（`AppDelegate` の起動の終わり）呼ぶこと。早すぎると強調の色が読み込まれない（段階 F1）。
    /// タブの文字は、iOS の版によっては受け付けられず、標準の字体のままになることがある。
    static func applyToSystemBars() {
        guard let base = UIFont(name: maruName, size: 17) else {
            return
        }
        let largeTitle = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: base.withSize(baseSize(.largeTitle)))
        let inlineTitle = UIFontMetrics(forTextStyle: .headline).scaledFont(for: base.withSize(baseSize(.headline)))
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitle]
        UINavigationBar.appearance().titleTextAttributes = [.font: inlineTitle]
        let tabTitle = base.withSize(10)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabTitle], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabTitle], for: .selected)
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
