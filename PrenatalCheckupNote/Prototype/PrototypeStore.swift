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
