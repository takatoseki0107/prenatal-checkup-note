#if DEBUG
import Observation

/// 開発用の切り替え。開発用ビルドだけに含める。
@Observable
final class DeveloperSettings {
    static let shared = DeveloperSettings()

    struct SaveFailure: Error {}

    /// オンにすると、保存がすべて失敗する（S-08）。失敗しても何も消えないことを確かめるため。アプリを終了すると、オフに戻る。
    var failsSaving = false
}
#endif
