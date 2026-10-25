import Foundation
import Observation

/// お知らせを押されたことを、画面に伝える（要件定義 v0.4 の R-46）。
///
/// お知らせを押したときの知らせは、iPhone から `AppDelegate` に届く。画面（`ContentView`）はそれを直接は受け取れないので、
/// ここに「次の健診を開く」を置いておき、画面が見て開く。アプリが閉じていて、押されて起動したときは、
/// 画面ができる前に知らせが届くことがある。そのときも、置いておいた印を画面ができてから読むので、取りこぼさない。
@Observable
final class NotificationTapRelay {
    static let shared = NotificationTapRelay()

    /// 「次の健診」を開くのを待っているか。画面が開いたら `false` に戻す。
    private(set) var opensNextCheckup = false

    /// お知らせが押された。このアプリの健診のお知らせなら、「次の健診」を開く印を置く。
    func receive(identifier: String) {
        guard ReminderPlan.opensNextCheckup(identifier: identifier) else {
            return
        }
        opensNextCheckup = true
    }

    /// 画面が「次の健診」を開いた。
    func didOpenNextCheckup() {
        opensNextCheckup = false
    }
}
