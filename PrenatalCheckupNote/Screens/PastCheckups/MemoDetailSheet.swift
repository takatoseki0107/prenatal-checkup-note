import SwiftUI

/// 過去の健診後メモを見る・直す・削除するシート（要件定義 v0.4 の 4 章「健診後メモを見る / 直す」、R-18、R-19）。
///
/// 開くと「見る」。右上の「編集」で「健診後メモを直す」に変わる。直すのは「保存」ボタン式で、書きかけは残さない（R-72）。
/// 直したら・削除したら、元に戻すの帯で戻せる。
/// 写真（段階 E）は、見る画面で小さく並べ、押すと大きく出す。直す画面では、足す・外すとすぐ保存する（元に戻せる）。
struct MemoDetailSheet: View {
    let memoID: UUID

    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var visitDate = Date.now
    @State private var memoBody = ""
    @State private var items: [EditableItem] = []
    /// 削除して閉じる途中か。閉じる間に「見つかりませんでした」を出さないため。
    @State private var isClosing = false
    @State private var isConfirmingCancel = false
    @State private var isConfirmingDelete = false
    /// 直す画面で、読み込んでいる写真の数。0 でなければ保存できない。
    @State private var loadingPhotoCount = 0

    var body: some View {
        NavigationStack {
            Group {
                if let memo {
                    if isEditing {
                        editForm
                    } else {
                        MemoView(memo: memo, photos: store.photos(forMemo: memo.id), isAgeShown: store.showsGestationalAge)
                    }
                } else if !isClosing {
                    ContentUnavailableView(
                        "このメモは見つかりませんでした",
                        systemImage: "doc.questionmark",
                        description: Text("削除された可能性があります。")
                    )
                }
            }
            .navigationTitle(isEditing ? "健診後メモを直す" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            if hasChanges {
                                isConfirmingCancel = true
                            } else {
                                isEditing = false
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            save()
                        }
                        .disabled(!canSave || !hasChanges || loadingPhotoCount > 0)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("編集") {
                            startEditing()
                        }
                        .disabled(memo == nil)
                    }
                }
            }
            // 直したあとの元に戻すの帯は、シートの上にも出す（後ろの画面の帯はシートに隠れるため）。
            // 直す画面では、写真を外したときだけ出す。
            .safeAreaInset(edge: .bottom) {
                if showsUndoBar {
                    UndoBar()
                        .background(AppColors.background)
                        // 下の帯は、文字サイズ最大でも画面の多くを占めないよう、大きさに上限を付ける（段階 F2）。
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
            }
            .animation(.default, value: store.pendingUndo)
            .alert("変更を破棄しますか？", isPresented: $isConfirmingCancel) {
                Button("編集を続ける", role: .cancel) {}
                Button("破棄", role: .destructive) {
                    isEditing = false
                }
            } message: {
                Text("保存していない変更は消えます。")
            }
            // 削除の前に、消えるものを示して確かめる。「やめる」を主ボタンにする（R-19）。
            .alert("このメモを削除しますか？", isPresented: $isConfirmingDelete) {
                Button("やめる", role: .cancel) {}
                Button("削除する", role: .destructive) {
                    delete()
                }
            } message: {
                Text(deleteMessage)
            }
        }
        // 「健診後メモを直す」の間は、変更があってもなくても、下にスワイプでは閉じない。写真を読み込んでいる間も閉じない。抜けるのは「キャンセル」か「保存」。
        // 変更があるときだけ止める形だと、日本語の変換を確定する前の文字がまだ変更に数えられず、
        // そのすきにスワイプで閉じられて、直しかけの内容が消えた（B5 の画面の確認で見つかった）。
        .interactiveDismissDisabled(isEditing || loadingPhotoCount > 0)
        // シートの上で起きた失敗は、シートの上で知らせる（ADR 0009）。
        .noteErrorAlert(store)
    }

    // MARK: - 直す画面

    private var editForm: some View {
        Form {
            Section {
                DatePicker("受診日", selection: $visitDate, displayedComponents: .date)
                    // 日付はグレゴリオ暦・日本時間で決める（R-90）。
                    .environment(\.calendar, .japan)
                    .environment(\.timeZone, Calendar.japan.timeZone)
            }
            Section("先生から聞いたこと・次までにすること") {
                TextField("先生の説明や、次の健診までにすること", text: $memoBody, axis: .vertical)
                    .lineLimit(4...)
            }
            MemoPhotosSection(
                memoID: memoID,
                photos: store.photos(forMemo: memoID),
                loadingCount: $loadingPhotoCount,
                footer: "写真は、足す・外すとすぐ保存されます（「キャンセル」でも戻りません）。外した写真は、下の「元に戻す」で戻せます。"
            )
            if !items.isEmpty {
                Section("この健診で聞いたこと") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("質問\(item.number)")
                                .font(.maru(.caption))
                                .foregroundStyle(.secondary)
                            TextField("質問", text: $item.questionText, axis: .vertical)
                            Text("先生の答え（任意）")
                                .font(.maru(.caption))
                                .foregroundStyle(.secondary)
                            TextField("先生の答え", text: $item.answer, axis: .vertical)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Section {
                Button("このメモを削除する", role: .destructive) {
                    isConfirmingDelete = true
                }
            } footer: {
                Text("過去のメモを直しても、いま「聞きたいこと」で丸を付けている質問は、このメモに入りません。")
            }
        }
        .appBackground()
    }

    // MARK: - 値

    private var memo: CheckupMemo? {
        store.memos.first { $0.id == memoID }
    }

    private var title: String {
        "\(memo?.visitDay?.displayText ?? "")の健診"
    }

    /// 削除の確認の文。消えるもの（質問の数・写真の枚数）を示す（R-19）。
    private var deleteMessage: String {
        let date = memo?.visitDay?.displayText ?? ""
        let count = memo?.items.count ?? 0
        let photoCount = store.photos(forMemo: memoID).count
        let photos = photoCount > 0 ? "、写真（\(photoCount)枚）" : ""
        return "\(date)の健診後メモを削除します。先生の話のメモと、この健診で聞いたこと（\(count)件）と答え\(photos)が、すべて消えます。"
    }

    /// 保存できるか。質問の文は必須（空白だけも空）。本文も質問も写真もないメモにはしない（R-12）。
    private var canSave: Bool {
        items.allSatisfy { InputText.normalized($0.questionText) != nil }
            && MemoSheetRules.canSave(body: memoBody, includedQuestionCount: items.count, photoCount: store.photos(forMemo: memoID).count)
    }

    /// 元に戻すの帯を出すか。見る画面ではいつも、直す画面では写真を外したときだけ。
    private var showsUndoBar: Bool {
        guard let undo = store.pendingUndo else {
            return false
        }
        if case .removedPhoto = undo {
            return true
        }
        return !isEditing
    }

    /// 保存されているメモと、画面の内容が違うか。
    private var hasChanges: Bool {
        guard isEditing, let memo else {
            return false
        }
        if CalendarDay(visitDate) != memo.visitDay || memoBody != memo.body {
            return true
        }
        let saved = Dictionary(uniqueKeysWithValues: memo.items.map { ($0.id, ($0.questionText, $0.answer)) })
        return items.contains { item in
            guard let before = saved[item.id] else {
                return true
            }
            return before.0 != item.questionText || before.1 != item.answer
        }
    }

    // MARK: - 操作

    private func startEditing() {
        guard let memo else {
            return
        }
        visitDate = (memo.visitDay ?? CalendarDay(.now)).date(hour: 12)
        memoBody = memo.body
        items = memo.sortedItems.enumerated().map { offset, item in
            EditableItem(id: item.id, number: offset + 1, questionText: item.questionText, answer: item.answer)
        }
        isEditing = true
    }

    private func save() {
        let day = CalendarDay(visitDate)
        let body = memoBody
        let edits = items.map { MemoItemEdit(id: $0.id, questionText: $0.questionText, answer: $0.answer) }
        let result: Void? = store.perform {
            try $0.updateMemo(id: memoID, visitDay: day, body: body, items: edits, now: .now)
        }
        if result != nil {
            // 直したら「見る」に戻る。帯の「元に戻す」で、直す前に戻せる（R-18）。
            isEditing = false
        }
    }

    private func delete() {
        let result: Void? = store.perform { try $0.deleteMemo(id: memoID) }
        if result != nil {
            // 閉じたあと、「健診の記録」の画面の帯の「元に戻す」で戻せる（R-19）。
            isClosing = true
            dismiss()
        }
    }
}

/// 健診後メモを見る画面（R-18 の「見る」）。写真は小さく並べ、押すと大きく出す（段階 E）。いちばん下から、文章で共有できる（段階 D）。
private struct MemoView: View {
    let memo: CheckupMemo
    let photos: [MemoPhoto]
    /// 「妊娠週数を表示する」。オフなら、共有の文章にも週数を入れない。
    let isAgeShown: Bool

    /// 大きく出している写真。出していなければ `nil`。
    @State private var viewing: ViewingPhoto?

    var body: some View {
        List {
            if !memo.body.isEmpty {
                Section("先生から聞いたこと・次までにすること") {
                    Text(memo.body)
                        .textSelection(.enabled)
                }
            }
            if !photos.isEmpty {
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                            Button {
                                viewing = ViewingPhoto(id: photo.id)
                            } label: {
                                PhotoThumbnail(thumbnailData: photo.thumbnailData, number: offset + 1, size: 96)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("押すと大きく表示します")
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("写真（\(photos.count)枚）")
                } footer: {
                    Text("押すと大きく表示します。指で広げると拡大できます。")
                }
            }
            if !memo.items.isEmpty {
                Section("この健診で聞いたこと") {
                    ForEach(memo.sortedItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.questionText)
                                .font(.maru(.headline))
                            Text(item.answer.isEmpty ? "答えのメモなし" : "先生の答え：\(item.answer)")
                                .font(.maru(.subheadline))
                                .foregroundStyle(item.answer.isEmpty ? .secondary : .primary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            Section {
                NavigationLink {
                    ShareTextView(text: shareText)
                } label: {
                    Label("この健診後メモを共有する", systemImage: "square.and.arrow.up")
                }
            }
        }
        .appBackground()
        .fullScreenCover(item: $viewing) { viewing in
            PhotoViewer(photos: photos, selection: viewing.id)
        }
    }

    /// 共有する文章。週数は「妊娠週数を表示する」がオンのときだけ入れる。写真は入れない（R-86）。
    private var shareText: String {
        var title = "\(memo.visitDay?.displayText ?? "日付なし")の健診"
        if let ageText = GestationalAgeDisplay.text(for: memo.gestationalAgeAtVisit, isShown: isAgeShown) {
            title += "（\(ageText)）"
        }
        return ShareText.memo(
            title: title,
            body: memo.body,
            items: memo.sortedItems.map { ShareText.MemoItem(question: $0.questionText, note: $0.note, answer: $0.answer) }
        )
    }
}

/// 直す画面の「この健診で聞いたこと」の 1 件。
private struct EditableItem: Identifiable {
    let id: UUID
    /// 画面に出す番号（質問 1、質問 2…）。
    let number: Int
    var questionText: String
    var answer: String
}

/// 大きく出す写真の ID。`fullScreenCover(item:)` に渡すため。
private struct ViewingPhoto: Identifiable {
    let id: UUID
}
