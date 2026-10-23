import Foundation

/// 確認記録（ある健診で、ある質問を確認した記録）の状態。要件定義 10章・11章。
///
/// 保存するときは `rawValue` の文字列を使う（`#Predicate` で絞り込めるようにするため。要件定義 10章「列挙型」）。
/// 画面の試作（段階1）とデータの核（段階2）の両方で使うため、特定のアクターに縛らない（`nonisolated`）。
nonisolated enum CheckStatus: String, CaseIterable, Hashable, Sendable {
    /// 未確認。まだ聞いていない。
    case unconfirmed
    /// 回答済み。
    case answered
    /// 持ち越し。行先は健診の完了時に選ぶ。
    case carriedOver
    /// 取り下げ。
    case withdrawn

    /// 画面に出す名前。
    var displayName: String {
        switch self {
        case .unconfirmed: "未確認"
        case .answered: "回答済み"
        case .carriedOver: "持ち越し"
        case .withdrawn: "取り下げ"
        }
    }
}
