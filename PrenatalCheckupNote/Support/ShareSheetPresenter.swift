import UIKit

/// 文章を共有シートで送るか印刷するために、共有シートを開く。要件定義 5章 F-16、ADR 0004。
///
/// 共有シートには、文章と一緒に印刷用の項目（`UISimpleTextPrintFormatter`）を渡す。
/// 文章だけでは共有シートに「プリント」が出ないため（TV-04）。
///
/// SwiftUI の `.sheet` で包まず、いま手前にある画面から UIKit で直接開く。
/// 包む方法では、共有シートが閉じたときに空のシートが残らないよう、表示の状態を戻す処理が要る。
/// 開くだけなら直接開くほうが単純で、TV-04 の実機確認でもこの方法を使った。
enum ShareSheetPresenter {
    /// 印刷するときの余白（ポイント）。1インチ。
    private static let printMargin: CGFloat = 72

    static func present(text: String) {
        let printFormatter = UISimpleTextPrintFormatter(text: text)
        printFormatter.perPageContentInsets = UIEdgeInsets(
            top: printMargin,
            left: printMargin,
            bottom: printMargin,
            right: printMargin
        )

        let controller = UIActivityViewController(
            activityItems: [text, printFormatter],
            applicationActivities: nil
        )
        topViewController()?.present(controller, animated: true)
    }

    /// いま一番手前に表示されている画面を探す。SwiftUI の画面の上に、UIKit の共有シートを重ねて表示するために使う。
    private static func topViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = windowScene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
