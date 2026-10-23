import Foundation
import Observation

/// 健診タブの画面遷移の道のり（path）を持つ。
///
/// 「診察を始める」のように、データを変えてから次の画面へ進むボタンがあるため、
/// 画面から道のりに直接積めるよう、環境（`@Environment`）で渡す。
@Observable
final class PrototypeNavigator {
    var path: [PrototypeRoute] = []

    /// 画面を1つ進める。
    func push(_ route: PrototypeRoute) {
        path.append(route)
    }

    /// 健診詳細まで戻る。健診を完了した後に、健診モードの画面をまとめて閉じるのに使う。
    ///
    /// 道のりに健診詳細がなければ、健診詳細だけを開いた状態にする。
    func popToAppointment(_ appointmentID: UUID) {
        if let index = path.firstIndex(of: .appointment(appointmentID)) {
            path.removeSubrange(path.index(after: index)...)
        } else {
            path = [.appointment(appointmentID)]
        }
    }
}
