import SwiftUI
import UIKit

/// 健診モード：診察中（ワイヤー2・3）。要件定義 6章、11章#5〜#8・#18。
///
/// 質問を並び順に1問ずつ大きく表示し、1回押すだけで「回答済み」「持ち越し」を記録する。
/// 記録した直後は、下のバナーから取り消せる。記録済みの質問を開くと、操作は取り消しだけになる（ワイヤー3）。
/// 短いメモは保存ボタンを置かず、入力欄を離れたとき（次の質問へ移る、記録する、一時停止、アプリが背面に回る）に保存する。
struct DuringExamView: View {
    let appointmentID: UUID

    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeNavigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// いま表示している質問の位置（取り下げ以外の記録の中での位置）。
    @State private var currentIndex = 0
    /// 短いメモの入力内容。質問を移るときに、保存済みの内容（未保存の入力があればそれ）を読み込む。
    @State private var memoDraft = ""
    /// 直前に記録した操作。バナーで取り消せるようにする。
    @State private var lastAction: RecordedAction?
    @State private var isShowingQuestionList = false
    @State private var hasLoaded = false
    @FocusState private var isMemoFocused: Bool

    /// 番号の列を出す質問の数の上限。多いときと文字が大きいときは、質問一覧から移動する。
    private let maxQuestionsForNumberStrip = 6

    private var checks: [PrototypeCheck] {
        store.data.appointment(id: appointmentID)?.activeChecks ?? []
    }

    private var currentCheck: PrototypeCheck? {
        checks.indices.contains(currentIndex) ? checks[currentIndex] : nil
    }

    var body: some View {
        Group {
            if let check = currentCheck {
                content(for: check)
            } else {
                ContentUnavailableView(
                    "聞く質問がありません",
                    systemImage: "questionmark.circle",
                    description: Text("診察前の画面で、質問を追加してください。")
                )
            }
        }
        .navigationTitle("診察中")
        .navigationBarTitleDisplayMode(.inline)
        // 戻るボタンの代わりに「一時停止」を置く。誤って戻らないよう、スワイプで戻る操作も止まる。
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("一時停止") {
                    commitMemo()
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    commitMemo()
                    isShowingQuestionList = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                        Text("\(currentIndex + 1) / \(checks.count)")
                            .monospacedDigit()
                    }
                }
                .accessibilityLabel("質問一覧を開く。\(checks.count)問中\(currentIndex + 1)問目")
                .disabled(checks.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingQuestionList) {
            DuringQuestionListSheet(appointmentID: appointmentID, currentIndex: currentIndex) { index in
                show(index)
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            // 最初は、まだ聞いていない質問のうち一番上から始める。
            currentIndex = checks.firstIndex { $0.status == .unconfirmed } ?? 0
            loadDraft()
        }
        .onChange(of: isMemoFocused) { _, isFocused in
            if !isFocused {
                commitMemo()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                commitMemo()
            }
        }
    }

    // MARK: - 画面

    private func content(for check: PrototypeCheck) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if checks.count <= maxQuestionsForNumberStrip && !dynamicTypeSize.isAccessibilitySize {
                    QuestionNumberStrip(
                        checks: checks,
                        currentIndex: currentIndex,
                        unsavedCheckIDs: Set(store.data.unsavedMemos.keys)
                    ) { index in
                        show(index)
                    }
                }

                QuestionCard(number: currentIndex + 1, text: check.questionText, status: check.status)

                memoSection(for: check)

                actionSection(for: check)

                HStack {
                    Button("‹ 前の質問") {
                        show(currentIndex - 1)
                    }
                    .disabled(currentIndex == 0)
                    Spacer()
                    Button("次の質問 ›") {
                        show(currentIndex + 1)
                    }
                    .disabled(currentIndex >= checks.count - 1)
                }
                .frame(minHeight: 44)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if let lastAction {
                    RecordedBanner(message: lastAction.message) {
                        undo(lastAction)
                    }
                }
                Button {
                    commitMemo()
                    navigator.push(.afterExam(appointmentID))
                } label: {
                    Text("診察を終える")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func memoSection(for check: PrototypeCheck) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("短いメモ（任意・入力欄を離れると保存）")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("一言メモ", text: $memoDraft, axis: .vertical)
                .lineLimit(2...4)
                .focused($isMemoFocused)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).stroke(.separator))
            if store.data.unsavedMemos[check.id] != nil {
                HStack {
                    Label("メモ未保存", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("再試行") {
                        retryCurrentMemo()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private func actionSection(for check: PrototypeCheck) -> some View {
        if check.status == .unconfirmed {
            // 文字が大きいときは、ボタンを縦に並べる。
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Button {
                    record(.carriedOver)
                } label: {
                    Text("持ち越し")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.bordered)

                Button {
                    record(.answered)
                } label: {
                    Text("回答済み")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    undoStatus(of: check)
                } label: {
                    Text(check.status == .answered ? "回答を取り消す" : "持ち越しを取り消す")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.bordered)
                Text("取り消すと未確認に戻ります。メモは残ります。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 操作

    /// 指定した位置の質問を表示する。移る前に、いまの質問のメモを保存する。
    private func show(_ index: Int) {
        guard checks.indices.contains(index) else { return }
        commitMemo()
        currentIndex = index
        loadDraft()
    }

    /// いまの質問のメモを入力欄に読み込む。未保存の入力があれば、それを優先する。
    private func loadDraft() {
        guard let check = currentCheck else {
            memoDraft = ""
            return
        }
        memoDraft = store.data.unsavedMemos[check.id] ?? check.answerMemo
    }

    /// 入力欄を離れたときなどに、メモを保存する。内容が変わっていなければ何もしない。
    private func commitMemo() {
        guard let check = currentCheck else { return }
        let hasUnsavedMemo = store.data.unsavedMemos[check.id] != nil
        guard memoDraft != check.answerMemo || hasUnsavedMemo else { return }
        store.saveMemo(memoDraft, checkID: check.id, in: appointmentID)
    }

    /// 画面の「再試行」。その時点で最新の入力（入力欄の内容）を保存する。
    private func retryCurrentMemo() {
        guard let check = currentCheck else { return }
        store.saveMemo(memoDraft, checkID: check.id, in: appointmentID)
    }

    /// 「回答済み」「持ち越し」を記録し、次の質問へ進む。
    private func record(_ status: CheckStatus) {
        guard let check = currentCheck else { return }
        commitMemo()
        store.data.setStatus(status, ofCheck: check.id, in: appointmentID)

        let action = RecordedAction(checkID: check.id, number: currentIndex + 1, status: status)
        lastAction = action
        // 画面を見ずに操作している人にも、記録できたことを伝える。
        UIAccessibility.post(notification: .announcement, argument: action.message)

        if currentIndex < checks.count - 1 {
            currentIndex += 1
            loadDraft()
        }
    }

    /// バナーの「取り消す」。直前の記録を未確認に戻す（11章#6・#8）。
    private func undo(_ action: RecordedAction) {
        store.data.setStatus(.unconfirmed, ofCheck: action.checkID, in: appointmentID)
        lastAction = nil
    }

    /// 記録済みの質問を開いたときの「回答を取り消す」「持ち越しを取り消す」。
    private func undoStatus(of check: PrototypeCheck) {
        commitMemo()
        store.data.setStatus(.unconfirmed, ofCheck: check.id, in: appointmentID)
        if lastAction?.checkID == check.id {
            lastAction = nil
        }
    }
}

/// 直前に記録した操作。
private struct RecordedAction: Equatable {
    let checkID: UUID
    let number: Int
    let status: CheckStatus

    var message: String {
        "質問\(number)を\(status.displayName)にしました"
    }
}

// MARK: - 部品

/// いまの質問を大きく出すカード。
private struct QuestionCard: View {
    let number: Int
    let text: String
    let status: CheckStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("質問 \(number)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if status != .unconfirmed {
                    StatusTag(status: status)
                }
            }
            Text(text)
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(.fill.tertiary))
        .accessibilityElement(children: .combine)
    }
}

/// 回答済み・持ち越しの印。回答済みは塗り、持ち越しは枠線にして、色だけに頼らず見分けられるようにする。
struct StatusTag: View {
    let status: CheckStatus

    var body: some View {
        switch status {
        case .answered:
            Text(status.displayName)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor))
        case .carriedOver:
            Text(status.displayName)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .overlay(Capsule().stroke(.primary, lineWidth: 1.5))
        case .unconfirmed, .withdrawn:
            Text(status.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// 質問の番号の列。質問が少ないときの近道。正式な入口は質問一覧（ワイヤー2b）。
private struct QuestionNumberStrip: View {
    let checks: [PrototypeCheck]
    let currentIndex: Int
    let unsavedCheckIDs: Set<UUID>
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(checks.enumerated()), id: \.element.id) { offset, check in
                let isCurrent = offset == currentIndex
                Button {
                    onSelect(offset)
                } label: {
                    Text(label(number: offset + 1, status: check.status))
                        .font(.footnote.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(check.status == .answered ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(fillColor(status: check.status, isCurrent: isCurrent))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(strokeColor(status: check.status, isCurrent: isCurrent), lineWidth: isCurrent ? 3 : 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityText(number: offset + 1, check: check, isCurrent: isCurrent))
            }
        }
    }

    private func label(number: Int, status: CheckStatus) -> String {
        switch status {
        case .answered: "\(number) 回答済"
        case .carriedOver: "\(number) 持越"
        case .unconfirmed, .withdrawn: "\(number)"
        }
    }

    private func fillColor(status: CheckStatus, isCurrent: Bool) -> Color {
        switch status {
        case .answered: Color.accentColor
        case .carriedOver: Color.clear
        case .unconfirmed, .withdrawn: isCurrent ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12)
        }
    }

    private func strokeColor(status: CheckStatus, isCurrent: Bool) -> Color {
        if isCurrent {
            return status == .answered ? Color.primary : Color.accentColor
        }
        return status == .carriedOver ? Color.primary : Color.clear
    }

    private func accessibilityText(number: Int, check: PrototypeCheck, isCurrent: Bool) -> String {
        var parts = ["質問\(number)", check.status.displayName]
        if isCurrent {
            parts.append("表示中")
        }
        if unsavedCheckIDs.contains(check.id) {
            parts.append("メモ未保存")
        }
        return parts.joined(separator: "、")
    }
}

/// 記録した直後に出すバナー。「取り消す」で直前の記録を戻せる。
private struct RecordedBanner: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("取り消す", action: onUndo)
                .font(.subheadline.bold())
                .foregroundStyle(Color(red: 0.66, green: 0.76, blue: 1.0))
                .frame(minHeight: 44)
                .padding(.horizontal, 10)
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.16)))
    }
}

#Preview("標準") {
    let store = PrototypeStore()
    NavigationStack {
        DuringExamView(appointmentID: store.data.currentAppointmentID)
    }
    .environment(store)
    .environment(PrototypeNavigator())
}
