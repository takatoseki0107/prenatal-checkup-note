import Foundation
import SwiftData

/// 起動したときに、保存場所を開いて準備する。
enum AppLaunch {
    case ready(NoteStore)
    case failed(String)

    static func start(now: Date = .now) -> AppLaunch {
        do {
            let container = try AppDataStore.makeAppContainer()
            let service = NoteService(context: ModelContext(container), persist: savesData)
            try service.prepareInitialData(now: now)
            return .ready(NoteStore(container: container, service: service))
        } catch {
            return .failed("データの保存場所を開けませんでした。アプリを終了して、開き直してください。")
        }
    }

    /// 保存の処理。開発用ビルドでは、開発用メニューから失敗させられる（S-08）。
    private static func savesData(_ context: ModelContext) throws {
        #if DEBUG
        if DeveloperSettings.shared.failsSaving {
            throw DeveloperSettings.SaveFailure()
        }
        #endif
        try context.save()
    }
}
