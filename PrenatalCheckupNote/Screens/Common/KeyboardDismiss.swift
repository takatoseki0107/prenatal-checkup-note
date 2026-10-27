import SwiftUI
import UIKit

extension View {
    /// 入力のあとにキーボードを閉じられるようにする（段階 F）。
    ///
    /// 複数行の入力欄では、改行のキーが改行になるので、iPhone 標準のキーボードでは閉じる方法がなかった
    /// （キーボードに閉じるボタンがある Simeji などでは閉じられた。実機で開発者が見つけた）。
    /// - キーボードの上に「完了」のボタンを出す。押すとキーボードを閉じる。
    /// - 一覧を下に引っぱると、指に合わせてキーボードが閉じる。
    /// 入力欄のある画面（シートの中なら NavigationStack の内側）に付ける。
    func keyboardDismissTools() -> some View {
        scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        // いま入力している欄から、入力の役目を外す（どの欄でも同じ書き方で閉じられる）。
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                }
            }
    }
}
