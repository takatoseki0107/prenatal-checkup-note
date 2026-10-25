import Foundation
import Observation

/// いま開いているタブとシートを、1 か所で持つ。
///
/// シートを 1 か所で開くのは、失敗の知らせをどこに出すかを決めやすくするため。
/// シートを開いている間は、後ろの画面の知らせはシートに隠れて出せない（段階 A の確認で見つかった）。
/// そこで、シートを開いていないときは一番下の画面で、開いているときはシートの上で知らせる。
@Observable
final class AppRouter {
    /// 下のタブ。
    nonisolated enum Tab: Hashable {
        /// 次の健診（日付・持ち物・聞きたいこと）。
        case next
        /// これまでの健診（健診後メモを見返す）。
        case past
    }

    /// 開くシート。
    nonisolated enum Sheet: Hashable, Identifiable {
        /// 質問を追加する。書きかけがあれば続きから（R-72）。
        case addQuestion
        /// すでにある質問を見る・直す・削除する。
        case editQuestion(UUID)
        /// 健診後メモを書く（入力途中のメモがあれば続きから）。開く前に書きかけを作っておく。
        case writeMemo
        /// 次の健診の日付と時刻を入れる・直す・消す。
        case nextCheckup
        /// 持ち物を見る・チェックする・足す・外す。
        case bringItems
        /// 過去の健診後メモを見る・直す・削除する。
        case memo(UUID)
        /// 設定。
        case settings

        var id: Self { self }
    }

    var selectedTab: Tab = .next
    /// 開いているシート。開いていなければ `nil`。
    var sheet: Sheet?
}
