import Foundation

/// 段階1の試作用データを作る。要件定義 17章「試作用データ」。
///
/// - 日付はすべて、渡された現在日時（起動した日時）からの相対で作る。いつ開いても、行先の候補の規則（日時が今以降）が同じように働くようにするため。
/// - 内容はすべて架空。症状の評価や医学的な判断を含む文言は使わない。
/// - 各状態は、標準データとの差分で作る。
nonisolated enum PrototypeDataFactory {
    /// 健診の予定時刻（10時30分）。
    private static let appointmentHour = 10
    private static let appointmentMinute = 30
    /// 前回・次回の健診と今回の健診の間隔（日）。
    private static let intervalDays = 28

    /// 今回の健診で聞く質問（ワイヤーの例文）。4件目は2行に折り返す長さにする。
    static let currentQuestionTexts = [
        "腰の痛みについて相談する",
        "仕事を続ける上で気をつけることを聞く",
        "次回の検査の内容を確認する",
        "里帰り出産の転院手続きの時期と、紹介状をいつまでに用意してもらえばよいかを聞く",
    ]

    /// 「質問が多い」状態で、今回の健診に足す質問。
    static let additionalQuestionTexts = [
        "健診の受診票の使い方を聞く",
        "次回までに用意する書類を確認する",
        "職場に出す書類の書き方を聞く",
        "分娩の予約をいつまでにすればよいか聞く",
        "上の子を連れて来てもよいか聞く",
        "待ち時間が短い時間帯を聞く",
        "駐車場の場所を確認する",
        "次回の検査の前に食事をしてよいか聞く",
    ]

    static let unassignedQuestionTexts = [
        "両親学級の申し込み方法を聞く",
        "出産する病院の見学ができるか聞く",
    ]

    static let withdrawnQuestionText = "マタニティマークの受け取り場所を聞く"

    /// 指定した状態の試作用データを作る。
    /// - Parameters:
    ///   - scenario: 作る状態。
    ///   - now: 現在日時。日付はすべてここからの相対で作る。
    ///   - calendar: 日付の計算に使う暦。テストでは固定したものを渡す。
    static func make(_ scenario: PrototypeScenario, now: Date, calendar: Calendar = .current) -> PrototypeData {
        var data = makeStandard(now: now, calendar: calendar)
        applyDifference(of: scenario, to: &data, now: now)
        return data
    }

    // MARK: - 標準データ

    /// 標準データ。
    /// - 健診3件：前回（28日前・完了）、今回（今日・予定・診察開始前）、次回（28日後・予定・記録なし）。
    /// - 今回の健診：未確認の質問4件。
    /// - 前回の健診：回答済み2件（回答メモあり・なし）、持ち越し1件（行先は今回の健診で、今回の4件のうち1件）。
    /// - そのほか：未割り当ての質問2件、取り下げた質問1件。
    static func makeStandard(now: Date, calendar: Calendar) -> PrototypeData {
        let today = appointmentTime(daysFromToday: 0, now: now, calendar: calendar)
        let previousDate = appointmentTime(daysFromToday: -intervalDays, now: now, calendar: calendar)
        let nextDate = appointmentTime(daysFromToday: intervalDays, now: now, calendar: calendar)

        let currentQuestions = currentQuestionTexts.map(makeQuestion)
        let previousAnsweredWithMemo = makeQuestion("母子健康手帳の記入欄について確認する")
        let previousAnsweredWithoutMemo = makeQuestion("次回の健診の持ち物を確認する")
        // 前回持ち越して、今回の健診に引き継いだ質問（今回の3件目）。
        let carriedQuestion = currentQuestions[2]
        let unassignedQuestions = unassignedQuestionTexts.map(makeQuestion)
        var withdrawnQuestion = makeQuestion(withdrawnQuestionText)
        withdrawnQuestion.withdrawnAt = previousDate

        let currentID = UUID()

        let previous = PrototypeAppointment(
            id: UUID(),
            scheduledAt: previousDate,
            clinicName: clinicName,
            status: .completed,
            examStartedAt: previousDate,
            memo: "",
            checks: [
                makeCheck(for: previousAnsweredWithMemo, status: .answered, memo: "次回の健診で記入してもらう"),
                makeCheck(for: previousAnsweredWithoutMemo, status: .answered),
                makeCheck(for: carriedQuestion, status: .carriedOver, carriedOverTo: currentID),
            ]
        )
        let current = PrototypeAppointment(
            id: currentID,
            scheduledAt: today,
            clinicName: clinicName,
            status: .scheduled,
            examStartedAt: nil,
            memo: "持ち物：母子健康手帳、保険証、受診票",
            checks: currentQuestions.map { makeCheck(for: $0, status: .unconfirmed) }
        )
        let next = PrototypeAppointment(
            id: UUID(),
            scheduledAt: nextDate,
            clinicName: clinicName,
            status: .scheduled,
            examStartedAt: nil,
            memo: "",
            checks: []
        )

        return PrototypeData(
            appointments: [previous, current, next],
            questions: [previousAnsweredWithMemo, previousAnsweredWithoutMemo]
                + currentQuestions
                + unassignedQuestions
                + [withdrawnQuestion],
            unsavedMemos: [:],
            currentAppointmentID: currentID
        )
    }

    // MARK: - 状態ごとの差分

    private static func applyDifference(of scenario: PrototypeScenario, to data: inout PrototypeData, now: Date) {
        switch scenario {
        case .standard, .completionSaveFails, .memoSaveFails, .sharePreview:
            break

        case .noQuestions:
            // 今回の記録を外す。前回から持ち越した質問は残り、未割り当てに戻る。
            let carriedQuestionIDs = Set(
                data.appointments.flatMap(\.checks)
                    .filter { $0.carriedOverToAppointmentID == data.currentAppointmentID }
                    .map(\.questionID)
            )
            let removedQuestionIDs = Set(data.currentChecks.map(\.questionID)).subtracting(carriedQuestionIDs)
            data.questions.removeAll { removedQuestionIDs.contains($0.id) }
            data.updateCurrentAppointment { $0.checks = [] }
            for index in data.appointments.indices {
                for checkIndex in data.appointments[index].checks.indices
                where data.appointments[index].checks[checkIndex].carriedOverToAppointmentID == data.currentAppointmentID {
                    data.appointments[index].checks[checkIndex].carriedOverToAppointmentID = nil
                }
            }

        case .noUnassignedQuestions:
            let unassignedIDs = Set(data.unassignedQuestions.map(\.id))
            data.questions.removeAll { unassignedIDs.contains($0.id) }

        case .noDestinations:
            // 次回の健診（今回より後の予定）を外す。
            let current = data.currentAppointment
            data.appointments.removeAll { $0.scheduledAt > current.scheduledAt }

        case .cancelNormal:
            data.updateCurrentAppointment { $0.checks[0].answerMemo = "痛む時間帯もあわせて伝える" }

        case .cancelWithRecords:
            data.updateCurrentAppointment { appointment in
                appointment.checks[0].status = .answered
                appointment.checks[0].answerMemo = "次回の健診でもう一度伝える"
                appointment.checks[1].status = .carriedOver
            }

        case .manyQuestions:
            let added = additionalQuestionTexts.map(makeQuestion)
            data.questions += added
            data.updateCurrentAppointment { appointment in
                appointment.checks += added.map { makeCheck(for: $0, status: .unconfirmed) }
            }

        case .unsavedMemoAtConfirm:
            data.updateCurrentAppointment { appointment in
                appointment.examStartedAt = now.addingTimeInterval(-30 * 60)
                appointment.checks[0].status = .answered
                appointment.checks[0].answerMemo = "次回の健診でもう一度伝える"
                appointment.checks[1].status = .carriedOver
                appointment.checks[2].status = .answered
                appointment.checks[3].status = .answered
            }
            let lastCheckID = data.currentChecks[3].id
            data.unsavedMemos[lastCheckID] = "紹介状の依頼は次回までに決める"
        }
    }

    // MARK: - 部品

    private static let clinicName = "サンプル産婦人科"

    private static func makeQuestion(_ text: String) -> PrototypeQuestion {
        PrototypeQuestion(id: UUID(), text: text, withdrawnAt: nil)
    }

    private static func makeCheck(
        for question: PrototypeQuestion,
        status: CheckStatus,
        memo: String = "",
        carriedOverTo appointmentID: UUID? = nil
    ) -> PrototypeCheck {
        PrototypeCheck(
            id: UUID(),
            questionID: question.id,
            questionText: question.text,
            status: status,
            answerMemo: memo,
            carriedOverToAppointmentID: appointmentID
        )
    }

    /// 今日から指定した日数後の、健診の予定時刻。
    private static func appointmentTime(daysFromToday days: Int, now: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: days, to: startOfToday) ?? startOfToday
        return calendar.date(bySettingHour: appointmentHour, minute: appointmentMinute, second: 0, of: day) ?? day
    }
}

extension PrototypeData {
    /// 今回の健診。
    nonisolated var currentAppointment: PrototypeAppointment {
        guard let appointment = appointment(id: currentAppointmentID) else {
            preconditionFailure("今回の健診がデータにありません")
        }
        return appointment
    }

    /// 今回の健診の確認記録。
    nonisolated var currentChecks: [PrototypeCheck] {
        currentAppointment.checks
    }

    /// 今回の健診を書き換える。
    nonisolated mutating func updateCurrentAppointment(_ update: (inout PrototypeAppointment) -> Void) {
        guard let index = appointments.firstIndex(where: { $0.id == currentAppointmentID }) else {
            preconditionFailure("今回の健診がデータにありません")
        }
        update(&appointments[index])
    }
}
