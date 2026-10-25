import Foundation
import Testing
@testable import PrenatalCheckupNote

/// はじめに・設定・出産予定日を消す、を一時的なファイルの保存場所で確かめる。
@MainActor
struct SettingsTests {
    private let now = TestDates.tokyo(2026, 10, 25, 11, 0)
    private let dueDate = TestDates.day(2027, 3, 1)

    @Test func newUserSeesTheOnboardingUntilFinishingIt() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        #expect(try service.profile()?.hasFinishedOnboarding == false)

        try service.finishOnboarding(dueDate: dueDate)

        let profile = try #require(try service.profile())
        #expect(profile.hasFinishedOnboarding)
        #expect(profile.dueDateNumber == dueDate.number)
    }

    @Test func skippingTheOnboardingLeavesNoDueDate() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)

        try service.finishOnboarding(dueDate: nil)

        let profile = try #require(try service.profile())
        #expect(profile.hasFinishedOnboarding)
        #expect(profile.dueDateNumber == nil)
    }

    @Test func existingUserWithRecordsSkipsTheOnboarding() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        try service.addQuestion(text: "腰の痛み", now: now)

        // 「はじめに」を作る前から使っていた人が、新しい版を開いたとき。
        try service.prepareInitialData(now: now)

        #expect(try service.profile()?.hasFinishedOnboarding == true)
    }

    @Test func savesTheSettingsTogetherAndKeepsPastWeeks() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        try service.finishOnboarding(dueDate: dueDate)
        try service.addQuestion(text: "腰の痛み", note: "", now: now)
        let id = try #require(try service.questions().first?.id)
        try service.setAsked(true, questionID: id)
        let today = TestDates.day(2026, 10, 25)
        try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "", excludedQuestionIDs: [], now: now)
        let saved = try service.saveMemo(try service.memoInputFromDraft(), now: now)

        let newDueDate = TestDates.day(2027, 3, 8)
        try service.updateSettings(dueDate: newDueDate, showsGestationalAge: false)

        let profile = try #require(try service.profile())
        #expect(profile.dueDateNumber == newDueDate.number)
        #expect(profile.showsGestationalAge == false)
        // 予定日を変えても、過去のメモは記録したときの予定日のまま（R-52）。
        #expect(try service.memo(id: saved.memoID)?.dueDateNumberAtVisit == dueDate.number)
    }

    @Test func clearsTheDueDateAndBringsItBack() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        try service.finishOnboarding(dueDate: dueDate)

        try service.clearDueDate()
        #expect(try service.profile()?.dueDateNumber == nil)
        #expect(service.pendingUndo == .clearedDueDate(dueDate.number))

        try service.undo()
        #expect(try service.profile()?.dueDateNumber == dueDate.number)
    }
}
