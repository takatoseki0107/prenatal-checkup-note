import Combine
import SwiftUI
import UIKit

extension View {
    /// 入力のあとにキーボードを閉じられるようにする（段階 F）。
    ///
    /// 複数行の入力欄では、改行のキーが改行になるので、iPhone 標準のキーボードでは閉じる方法がなかった
    /// （キーボードに閉じるボタンがある Simeji などでは閉じられた。実機で開発者が見つけた）。
    /// - キーボードのすぐ上に、横長の「完了」のボタンを出す。押すとキーボードを閉じる。
    /// - 一覧を下に引っぱると、指に合わせてキーボードが閉じる。
    /// 入力欄のある画面に付ける。
    func keyboardDismissTools() -> some View {
        modifier(KeyboardDismissBar())
    }

    /// キーボードが出た・閉じたことを知らせる。画面の下の帯を、入力中だけ隠すのに使う。
    ///
    /// 入力中に下の帯（保存のボタンなど）を出したままにすると、帯がキーボードの上に乗って入力欄が狭くなり、
    /// キーボードの上の「完了」とも重なって見えた（実機で開発者が見つけた）。
    func onKeyboardVisibilityChange(_ action: @escaping (Bool) -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            action(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            action(false)
        }
    }
}

/// キーボードのすぐ上に出す、横長の「完了」のボタン。
///
/// 最初は iOS 標準のキーボードの上の道具（`.toolbar` の `.keyboard`）で出したが、iOS 26 では右のはしに小さく浮かんで、
/// 下の帯と重なったり、押す場所がわかりにくかったりした（実機で開発者が見つけた）。
/// 画面の下の余白（`safeAreaInset`）として出すと、キーボードのすぐ上に、横いっぱいの押しやすいボタンとして置ける。
private struct KeyboardDismissBar: ViewModifier {
    /// キーボードが出ているか。出ている間だけボタンを出す。
    @State private var isKeyboardShown = false

    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if isKeyboardShown {
                    Button {
                        // いま入力している欄から、入力の役目を外す（どの欄でも同じ書き方で閉じられる）。
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Text("完了")
                            .font(.maru(.headline))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .accessibilityHint("キーボードを閉じます")
                    .transition(.opacity)
                }
            }
            .onKeyboardVisibilityChange { shown in
                withAnimation(.easeOut(duration: 0.2)) {
                    isKeyboardShown = shown
                }
            }
    }
}
