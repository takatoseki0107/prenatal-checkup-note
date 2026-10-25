import SwiftUI

/// 元に戻すの帯（要件定義 v0.4 の 4 章・R-60）。「◯◯しました」と「元に戻す」を、画面の下に数秒出す。
///
/// 戻せる操作がないときは何も出さない。時間で消すのは `NoteStore` が受け持つ。
struct UndoBar: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let undo = store.pendingUndo {
            HStack {
                Text(undo.message)
                    .font(.subheadline)
                Spacer()
                // iOS 26 では、帯の上の `.bordered` のボタンは背景がほとんど見えないので、塗りのあるボタンにする。
                Button("元に戻す") {
                    let undone = store.perform { try $0.undo() }
                    // 健診後メモの保存を戻したら、書いた内容のままメモのシートを開き直す（R-17）。
                    if case .savedMemo? = undone {
                        router.sheet = .writeMemo
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

extension PendingUndo {
    /// 帯に出す文。
    var message: String {
        switch self {
        case .deletedQuestion:
            "質問を削除しました"
        case .savedMemo:
            "健診後メモを保存しました"
        case .clearedNextCheckup:
            "次の健診の日付を消しました"
        case .removedBringItem(let item):
            "「\(item.name)」を持ち物から外しました"
        case .editedMemo:
            "健診後メモを直しました"
        case .deletedMemo:
            "健診後メモを削除しました"
        }
    }
}
