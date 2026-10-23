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
}
