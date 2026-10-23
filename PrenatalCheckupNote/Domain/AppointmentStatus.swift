import Foundation

/// 健診の状態。要件定義 10章。
///
/// 保存するときは `rawValue` の文字列を使う（要件定義 10章「列挙型」）。
nonisolated enum AppointmentStatus: String, CaseIterable, Hashable, Sendable {
    /// 予定。
    case scheduled
    /// 完了。
    case completed
    /// キャンセル。
    case cancelled

    /// 画面に出す名前。
    var displayName: String {
        switch self {
        case .scheduled: "予定"
        case .completed: "完了"
        case .cancelled: "キャンセル"
        }
    }
}
