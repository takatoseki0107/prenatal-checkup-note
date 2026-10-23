import Foundation

/// 健診タブの画面遷移。`NavigationStack` の道のり（path）に積む。要件定義 9章「enumの型付きルート」。
///
/// 健診のIDだけを持ち、画面を開いたときにデータから最新の内容を読む。
nonisolated enum PrototypeRoute: Hashable, Sendable {
    /// 健診詳細。
    case appointment(UUID)
    /// 健診モード：診察前（ワイヤー1・13）。
    case beforeExam(UUID)
    /// 健診モード：診察中（ワイヤー2・2b・3）。
    case duringExam(UUID)
    /// 健診モード：診察後（ワイヤー4〜9）。
    case afterExam(UUID)
    /// 共有プレビュー（ワイヤー12）。
    case sharePreview(UUID)
}
