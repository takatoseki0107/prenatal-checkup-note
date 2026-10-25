import Foundation
import SwiftData

/// 保存場所（SwiftData のコンテナ）を作る。要件定義 v0.4 の 1 章・6 章。
enum AppDataStore {
    /// このアプリのデータのモデル。
    static let schema = Schema([
        Question.self,
        CheckupMemo.self,
        MemoItem.self,
        NextCheckup.self,
        BringItem.self,
        PregnancyProfile.self,
        MemoDraft.self,
        QuestionDraft.self,
    ])

    /// 指定の場所に保存するコンテナ。iCloud とは同期しない（1 章）。
    ///
    /// テストでは一時的なファイルの場所を渡し、閉じて開き直しても残るかを確かめる（S-07）。
    static func makeContainer(url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// メモリの中だけの保存場所。プレビューに使う。
    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// アプリで使う、本当のデータの保存場所。
    ///
    /// サンプルデータ（段階 D）は、これとは別の場所に保存する。
    static func makeAppContainer() throws -> ModelContainer {
        let directory = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try makeContainer(url: directory.appending(path: "PrenatalCheckupNote.store"))
    }

    /// 画面のテスト（XCUITest）で使う保存場所。本当のデータとは別のフォルダーに置く。
    ///
    /// - Parameter resettingData: `true` なら、開く前にフォルダーごと消して、空から始める。
    static func makeUITestingContainer(resettingData: Bool) throws -> ModelContainer {
        let directory = URL.applicationSupportDirectory.appending(path: "UITesting", directoryHint: .isDirectory)
        if resettingData, FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try makeContainer(url: directory.appending(path: "PrenatalCheckupNote.store"))
    }
}
