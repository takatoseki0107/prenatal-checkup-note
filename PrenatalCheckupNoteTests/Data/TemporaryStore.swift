import Foundation
import SwiftData
@testable import PrenatalCheckupNote

/// テスト用の保存場所。メモリの中ではなく一時的なファイルに保存し、閉じて開き直せる（S-07）。
@MainActor
final class TemporaryStore {
    /// 保存を失敗させるかどうかの切り替え（S-08）。
    final class FailureSwitch {
        var shouldFail = false
    }

    struct SaveFailure: Error {}

    let url: URL
    let failures = FailureSwitch()
    private(set) var container: ModelContainer

    init() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PrenatalCheckupNoteTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appending(path: "Test.store")
        container = try AppDataStore.makeContainer(url: url)
    }

    /// この保存場所を使う窓口。`failures.shouldFail` を `true` にすると、保存が失敗する。
    func makeService() -> NoteService {
        let failures = failures
        return NoteService(context: ModelContext(container)) { context in
            if failures.shouldFail {
                throw SaveFailure()
            }
            try context.save()
        }
    }

    /// 保存場所を閉じて、同じファイルから開き直す。開き直したあとの窓口は `makeService()` で作り直す。
    func reopen() throws {
        container = try AppDataStore.makeContainer(url: url)
    }
}
