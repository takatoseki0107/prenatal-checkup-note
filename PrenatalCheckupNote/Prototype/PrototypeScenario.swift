import Foundation

/// 段階1で切り替えて確認する状態。要件定義 17章「段階1の状態切り替え」の11状態。
///
/// どの状態も標準データ（`standard`）を起点にし、その差分で作る。
nonisolated enum PrototypeScenario: String, CaseIterable, Identifiable, Hashable, Sendable {
    case standard
    case noQuestions
    case noUnassignedQuestions
    case noDestinations
    case cancelNormal
    case cancelWithRecords
    case manyQuestions
    case completionSaveFails
    case memoSaveFails
    case unsavedMemoAtConfirm
    case sharePreview

    var id: String { rawValue }

    /// 切り替え画面に出す名前。
    var title: String {
        switch self {
        case .standard: "標準"
        case .noQuestions: "質問0件"
        case .noUnassignedQuestions: "未割り当て0件"
        case .noDestinations: "行先候補なし"
        case .cancelNormal: "通常のキャンセル確認（未確認のみ）"
        case .cancelWithRecords: "入力済みの記録があるキャンセル"
        case .manyQuestions: "質問が多い（12件）"
        case .completionSaveFails: "完了の保存失敗"
        case .memoSaveFails: "メモの保存失敗"
        case .unsavedMemoAtConfirm: "未保存のメモがある最終確認"
        case .sharePreview: "共有プレビュー"
        }
    }

    /// 標準データとの違い。切り替え画面に出す。
    var summary: String {
        switch self {
        case .standard:
            "今回の健診に未確認の質問4件。前回は完了、次回は記録なし。未割り当て2件、取り下げ1件。"
        case .noQuestions:
            "今回の健診の質問を外す。「診察を始める」を押せないことを確かめる。"
        case .noUnassignedQuestions:
            "未割り当ての質問を外す。"
        case .noDestinations:
            "次回の健診を外す。持ち越し先は未割り当てだけになる。"
        case .cancelNormal:
            "今回の質問は未確認のまま、1件に短いメモがある。キャンセルの確認で、消えるメモの件数を出す。"
        case .cancelWithRecords:
            "今回の質問に回答済みと持ち越しがある。そのままキャンセルせず、案内を出す。"
        case .manyQuestions:
            "今回の健診の質問を12件にする。診察中の質問一覧で移動する。"
        case .completionSaveFails:
            "健診の完了を保存しようとすると失敗する。"
        case .memoSaveFails:
            "回答メモや短いメモを保存しようとすると失敗する。"
        case .unsavedMemoAtConfirm:
            "診察を始めた後で、保存に失敗した短いメモが1件ある。診察後の画面から始める。"
        case .sharePreview:
            "共有プレビューから始める。"
        }
    }

    /// この状態で、保存の失敗を起こすかどうかの初期値。切り替え画面で後から変えられる。
    var initialFailures: PrototypeFailures {
        switch self {
        case .completionSaveFails: PrototypeFailures(completionSave: true, memoSave: false)
        case .memoSaveFails: PrototypeFailures(completionSave: false, memoSave: true)
        default: PrototypeFailures()
        }
    }

    /// 切り替えた直後に開く画面。
    var startScreen: PrototypeStartScreen {
        switch self {
        case .unsavedMemoAtConfirm: .afterExam
        case .sharePreview: .sharePreview
        default: .appointmentDetail
        }
    }
}

/// 試作で、わざと起こす保存の失敗。
nonisolated struct PrototypeFailures: Hashable, Sendable {
    /// 健診の完了（最終確定）の保存に失敗する。要件定義 14章 P-02・C-12。
    var completionSave = false
    /// 回答メモ・短いメモの保存に失敗する。要件定義 14章 M-05・M-06。
    var memoSave = false
}

/// 状態を切り替えた直後に開く画面。
nonisolated enum PrototypeStartScreen: Hashable, Sendable {
    /// 今回の健診の健診詳細。
    case appointmentDetail
    /// 今回の健診の診察後の画面。
    case afterExam
    /// 今回の健診の共有プレビュー。
    case sharePreview
}
