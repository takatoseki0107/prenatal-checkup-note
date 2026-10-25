import SwiftUI

extension View {
    /// 保存の窓口で起きた失敗を知らせる。
    ///
    /// 知らせは、いま一番上に見えている画面に付ける。シートを開いている間は、後ろの画面では `isActive` を `false` にし、
    /// シートの側で出す（後ろの画面に付けた知らせは、シートに隠れて出ないまま終わるため。段階 A の確認で見つかった）。
    func noteErrorAlert(_ store: NoteStore, isActive: Bool = true) -> some View {
        alert(
            "うまくいきませんでした",
            isPresented: Binding {
                store.errorMessage != nil && isActive
            } set: { isShowing in
                if !isShowing {
                    store.errorMessage = nil
                }
            }
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
