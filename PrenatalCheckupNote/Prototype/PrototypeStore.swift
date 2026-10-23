import Foundation
import Observation

/// 段階1の画面が読み書きする、メモリ上だけのデータの置き場所。保存はしない。
///
/// 画面からは `@Environment(PrototypeStore.self)` で受け取る。
/// 段階3で、段階2のServiceと保存モデルに置き換える。要件定義 17章。
@Observable
final class PrototypeStore {
    /// いまの状態。
    private(set) var scenario: PrototypeScenario
    /// 画面に出すデータ。
    var data: PrototypeData
    /// わざと起こす保存の失敗。開発用の切り替え画面から変えられる。
    var failures: PrototypeFailures

    init(scenario: PrototypeScenario = .standard, now: Date = .now) {
        self.scenario = scenario
        self.data = PrototypeDataFactory.make(scenario, now: now)
        self.failures = scenario.initialFailures
    }

    /// 状態を切り替える。データは標準データから作り直す。
    func apply(_ scenario: PrototypeScenario, now: Date = .now) {
        self.scenario = scenario
        data = PrototypeDataFactory.make(scenario, now: now)
        failures = scenario.initialFailures
    }

    /// 回答メモ（診察中の短いメモを含む）を保存する。
    ///
    /// 保存の失敗を起こす設定のときは保存しない。
    /// 確認記録の状態（回答済み・持ち越し）は、メモの保存とは別に記録するため、メモの失敗では変わらない（11章「診察中の短いメモ」）。
    /// - Parameter keepsUnsavedOnFailure: 失敗したとき、入力を「未保存のメモ」として残すか。
    ///   診察中の短いメモでは残す。回答メモの編集画面では残さず、入力は画面に残して再試行させる。
    ///   編集画面の「キャンセル」で、その画面での変更を破棄できるようにするため（11章#18、14章 M-05・M-11）。
    /// - Returns: 保存できたら `true`。
    @discardableResult
    func saveMemo(_ text: String, checkID: UUID, in appointmentID: UUID, keepsUnsavedOnFailure: Bool = true) -> Bool {
        if failures.memoSave {
            if keepsUnsavedOnFailure {
                data.unsavedMemos[checkID] = text
            }
            return false
        }
        data.saveMemo(text, ofCheck: checkID, in: appointmentID)
        return true
    }

    /// 未保存のメモを、もう一度保存する。その時点で残っている最新の入力を保存する。
    ///
    /// 新しい内容の保存に成功した後は未保存のメモが残っていないため、古い入力で上書きすることはない（14章 M-09）。
    /// - Returns: 保存できたら `true`。未保存のメモがなければ何もせず `false`。
    @discardableResult
    func retryUnsavedMemo(checkID: UUID, in appointmentID: UUID) -> Bool {
        guard let text = data.unsavedMemos[checkID] else { return false }
        return saveMemo(text, checkID: checkID, in: appointmentID)
    }

    /// 状態を切り替えた直後に開く画面までの道のり。
    var startPath: [PrototypeRoute] {
        let currentID = data.currentAppointmentID
        switch scenario.startScreen {
        case .appointmentDetail:
            return [.appointment(currentID)]
        case .afterExam:
            return [.appointment(currentID), .afterExam(currentID)]
        case .sharePreview:
            return [.appointment(currentID), .sharePreview(currentID)]
        }
    }
}
