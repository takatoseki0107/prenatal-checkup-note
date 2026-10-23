import SwiftUI

/// 健診モード：診察前（ワイヤー1）と、質問がないときの空の状態（ワイヤー13）。要件定義 6章。
///
/// 今回の健診で聞く質問を確認し、並べ替え（上にあるほど先に聞く）、追加し、共有・印刷へ進む。
/// 「診察を始める」で診察開始日時を記録し、診察中の画面へ進む。
struct BeforeExamView: View {
    let appointmentID: UUID

    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeNavigator.self) private var navigator
    @State private var isAddingQuestion = false
    @State private var isPickingUnassignedQuestions = false

    var body: some View {
        if let appointment = store.data.appointment(id: appointmentID) {
            content(for: appointment)
        } else {
            ContentUnavailableView("健診が見つかりません", systemImage: "calendar.badge.exclamationmark")
        }
    }

    private func content(for appointment: PrototypeAppointment) -> some View {
        let activeChecks = appointment.activeChecks
        let unassignedQuestions = store.data.unassignedQuestions

        return List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(appointment.scheduledAt.appointmentDateTimeText + "・" + appointment.clinicName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ExamStageIndicator(current: .before)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            if activeChecks.isEmpty {
                Section {
                    EmptyQuestionsView {
                        isAddingQuestion = true
                    }
                }
            } else {
                Section {
                    ForEach(Array(activeChecks.enumerated()), id: \.element.id) { offset, check in
                        QuestionOrderRow(number: offset + 1, text: check.questionText)
                            .accessibilityActions {
                                // 長押しのドラッグを使えない場合（VoiceOver など）に備えて、1つずつ動かす操作を用意する。
                                if offset > 0 {
                                    Button("上へ移動") {
                                        move(from: offset, to: offset - 1)
                                    }
                                }
                                if offset < activeChecks.count - 1 {
                                    Button("下へ移動") {
                                        move(from: offset, to: offset + 2)
                                    }
                                }
                            }
                    }
                    .onMove { source, destination in
                        store.data.moveActiveChecks(in: appointmentID, fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        isAddingQuestion = true
                    } label: {
                        Label("質問を追加", systemImage: "plus")
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("聞きたいこと（\(activeChecks.count)件）")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("上から順に聞く・長押しで並べ替え")
                            .font(.caption)
                    }
                    .textCase(nil)
                }
            }

            Section {
                if unassignedQuestions.isEmpty {
                    LabeledContent("未割り当ての質問", value: "ありません")
                } else {
                    Button("未割り当てから選ぶ（\(unassignedQuestions.count)件）") {
                        isPickingUnassignedQuestions = true
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActions(for: appointment, hasQuestions: !activeChecks.isEmpty)
        }
        .navigationTitle("健診で聞くこと")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: PrototypeRoute.sharePreview(appointmentID)) {
                    Label("質問リストを共有・印刷", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $isAddingQuestion) {
            AddQuestionSheet { text in
                store.data.addQuestion(text, to: appointmentID)
            }
        }
        .sheet(isPresented: $isPickingUnassignedQuestions) {
            UnassignedQuestionPicker(questions: unassignedQuestions) { questionIDs in
                store.data.assign(questionIDs: questionIDs, to: appointmentID)
            }
        }
    }

    /// 画面の下に固定するボタン。診察を始める・再開する、または診察後の入力へ進む。
    private func bottomActions(for appointment: PrototypeAppointment, hasQuestions: Bool) -> some View {
        let isStarted = appointment.examStartedAt != nil
        // 初回の開始は、取り下げ以外の記録が1件以上あるときだけ。再開は件数を問わない（11章#4、E-01）。
        let canStart = hasQuestions || isStarted

        return VStack(spacing: 8) {
            Button {
                store.data.startExam(of: appointmentID, at: .now)
                navigator.push(.duringExam(appointmentID))
            } label: {
                Text(isStarted ? "診察を再開する" : "診察を始める")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStart)

            Text(startCaption(isStarted: isStarted, canStart: canStart))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink(value: PrototypeRoute.afterExam(appointmentID)) {
                Text(hasQuestions ? "診察中は使わず、診察後の入力へ進む" : "質問なしで健診を記録する")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(.bar)
    }

    private func startCaption(isStarted: Bool, canStart: Bool) -> String {
        if !canStart {
            "質問を追加すると始められます"
        } else if isStarted {
            "診察を始めた日時は、最初の記録のまま変わりません"
        } else {
            "始めると、この健診の質問文が固定されます"
        }
    }

    private func move(from offset: Int, to destination: Int) {
        store.data.moveActiveChecks(in: appointmentID, fromOffsets: IndexSet(integer: offset), toOffset: destination)
    }
}

/// 診察前の質問の1行。番号と質問文を出す。
private struct QuestionOrderRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// この健診で聞く質問がないときの表示（ワイヤー13）。
private struct EmptyQuestionsView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("この健診で聞くことはまだありません")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("日々の記録から質問を作るか、ここで追加できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onAdd) {
                Label("質問を追加", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

#Preview("標準") {
    let store = PrototypeStore()
    NavigationStack {
        BeforeExamView(appointmentID: store.data.currentAppointmentID)
    }
    .environment(store)
    .environment(PrototypeNavigator())
}

#Preview("質問0件") {
    let store = PrototypeStore(scenario: .noQuestions)
    NavigationStack {
        BeforeExamView(appointmentID: store.data.currentAppointmentID)
    }
    .environment(store)
    .environment(PrototypeNavigator())
}
