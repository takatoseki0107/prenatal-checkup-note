import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 健診後メモの写真の保存（段階 E の決まり、R-80〜R-85、R-12、R-19）を、一時的なファイルの保存場所で確かめる。
@MainActor
struct MemoPhotoTests {
    private let now = TestDates.tokyo(2026, 10, 26, 11, 0)
    private let today = TestDates.day(2026, 10, 26)

    /// 中身の決まった写真。保存の仕組みは画像の中身を見ないので、短いデータで足りる。
    private func photo(_ number: UInt8) -> PreparedPhoto {
        PreparedPhoto(imageData: Data([number, number, number]), thumbnailData: Data([number]))
    }

    @Test func savesAMemoWithOnlyAPhoto() throws {
        // 本文も聞いた質問もなくても、写真があれば保存できる（R-12 を広げた）。
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        try service.addPhoto(photo(1), memoID: draft.id, now: now)

        let result = try service.saveMemo(try service.memoInputFromDraft(), now: now)

        #expect(result.memoID == draft.id)
        #expect(try service.memoDraft() == nil)
        // 書きかけと同じ ID なので、写真はそのまま保存したメモの写真になる。
        #expect(try service.photos(memoID: result.memoID).map(\.imageData) == [Data([1, 1, 1])])
    }

    @Test func stillRefusesAnEmptyMemo() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.startMemoDraft(today: today, now: now)

        #expect(throws: NoteServiceError.emptyMemo) {
            try service.saveMemo(try service.memoInputFromDraft(), now: now)
        }
    }

    @Test func allowsUpToFivePhotos() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        for number in 1...5 {
            try service.addPhoto(photo(UInt8(number)), memoID: draft.id, now: now)
        }

        #expect(throws: NoteServiceError.tooManyPhotos) {
            try service.addPhoto(photo(6), memoID: draft.id, now: now)
        }
        #expect(try service.photos(memoID: draft.id).map(\.thumbnailData) == (1...5).map { Data([UInt8($0)]) })
    }

    @Test func addsOnlyToTheDraftOrASavedMemo() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        #expect(throws: NoteServiceError.notFound) {
            try service.addPhoto(photo(1), memoID: UUID(), now: now)
        }
    }

    @Test func keepsDraftPhotosAfterReopening() throws {
        // 選んだ写真は入力途中のメモに残り、アプリを起動し直しても残る。
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        try service.addPhoto(photo(7), memoID: draft.id, now: now)
        let draftID = draft.id

        try store.reopen()
        let reopened = store.makeService()

        #expect(try reopened.memoDraft()?.id == draftID)
        #expect(try reopened.photos(memoID: draftID).map(\.imageData) == [Data([7, 7, 7])])
    }

    @Test func discardingTheDraftRemovesItsPhotos() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        try service.addPhoto(photo(1), memoID: draft.id, now: now)
        let draftID = draft.id

        try service.discardMemoDraft()

        #expect(try service.photos(memoID: draftID).isEmpty)
        #expect(try service.allPhotos().isEmpty)
    }

    @Test func removesAPhotoAndBringsItBackWithTheImage() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        try service.addPhoto(photo(1), memoID: draft.id, now: now)
        let second = try service.addPhoto(photo(2), memoID: draft.id, now: now)
        try service.addPhoto(photo(3), memoID: draft.id, now: now)

        try service.removePhoto(id: second)
        #expect(try service.photos(memoID: draft.id).map(\.thumbnailData) == [Data([1]), Data([3])])
        #expect(service.pendingUndo?.message == "写真を外しました")

        try service.undo()
        let restored = try service.photos(memoID: draft.id)
        #expect(restored.map(\.id).contains(second))
        #expect(restored.map(\.imageData) == [Data([1, 1, 1]), Data([2, 2, 2]), Data([3, 3, 3])])
    }

    @Test func doesNotRemoveTheLastContentOfASavedMemo() throws {
        // 本文も質問もないメモの、最後の 1 枚は外せない（空のメモを残さない）。
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        let only = try service.addPhoto(photo(1), memoID: draft.id, now: now)
        try service.saveMemo(try service.memoInputFromDraft(), now: now)

        #expect(throws: NoteServiceError.emptyMemo) {
            try service.removePhoto(id: only)
        }
    }

    @Test func deletingAMemoRemovesItsPhotosAndUndoBringsThemBack() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "エコーで横向き", excludedQuestionIDs: [], now: now)
        try service.addPhoto(photo(1), memoID: draft.id, now: now)
        try service.addPhoto(photo(2), memoID: draft.id, now: now)
        let memoID = try service.saveMemo(try service.memoInputFromDraft(), now: now).memoID

        try service.deleteMemo(id: memoID)
        #expect(try service.allPhotos().isEmpty)

        try service.undo()
        #expect(try service.memo(id: memoID) != nil)
        #expect(try service.photos(memoID: memoID).map(\.imageData) == [Data([1, 1, 1]), Data([2, 2, 2])])
    }

    @Test func undoingTheSaveKeepsThePhotosOnTheDraft() throws {
        // 保存を元に戻すと、写真は入力途中のメモに戻る（同じ ID なので、そのまま残る）。
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        try service.addPhoto(photo(1), memoID: draft.id, now: now)
        let draftID = draft.id
        try service.saveMemo(try service.memoInputFromDraft(), now: now)

        try service.undo()

        #expect(try service.memoDraft()?.id == draftID)
        #expect(try service.photos(memoID: draftID).count == 1)
    }

    @Test func aMemoWithPhotosCanHaveAnEmptyBody() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "メモ", excludedQuestionIDs: [], now: now)
        try service.addPhoto(photo(1), memoID: draft.id, now: now)
        let memoID = try service.saveMemo(try service.memoInputFromDraft(), now: now).memoID

        try service.updateMemo(id: memoID, visitDay: today, body: "  ", items: [], now: now)

        #expect(try service.memo(id: memoID)?.body == "")
    }

    @Test func theStoreShowsTheDraftPhotos() throws {
        // 画面は `NoteStore.memoDraftPhotos` を見て、書きかけの写真を並べる。足す・外すのたびに読み直す。
        let temporary = try TemporaryStore()
        let store = NoteStore(container: temporary.container, service: temporary.makeService())
        store.perform { try $0.startMemoDraft(today: today, now: now) }
        let draftID = try #require(store.memoDraft?.id)

        let added = try #require(store.perform { try $0.addPhoto(photo(1), memoID: draftID, now: now) })
        #expect(store.memoDraftPhotos.map(\.id) == [added])

        store.perform { try $0.removePhoto(id: added) }
        #expect(store.memoDraftPhotos.isEmpty)
        guard case .removedPhoto(let snapshot)? = store.pendingUndo else {
            Issue.record("写真を外したあとに、元に戻すがない")
            return
        }
        #expect(snapshot.id == added)
    }

    @Test func keepsTheOtherPhotosWhenAPhotoFails() throws {
        // 読み込めない写真は保存の形にできないので、足す前に止まる。ほかの写真とメモはそのまま（R-85）。
        let store = try TemporaryStore()
        let service = store.makeService()
        let draft = try service.startMemoDraft(today: today, now: now)
        try service.addPhoto(photo(1), memoID: draft.id, now: now)

        #expect(throws: PhotoUnreadableError.self) {
            try service.addPhoto(try PhotoProcessing.prepare(Data("壊れた写真".utf8)), memoID: draft.id, now: now)
        }
        #expect(try service.photos(memoID: draft.id).count == 1)
    }
}
