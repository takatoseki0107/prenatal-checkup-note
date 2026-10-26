import Foundation
import Observation
import SwiftData

/// 画面に出すデータと、保存の窓口（`NoteService`）をつなぐ。
///
/// 画面は、ここに並んだデータを見て表示し、変えるときは `perform` で窓口の操作を呼ぶ。
/// 操作のあとは、成功しても失敗しても、保存場所から読み直す。画面が保存場所とずれないようにするため。
@Observable
final class NoteStore {
    private(set) var questions: [Question] = []
    private(set) var memos: [CheckupMemo] = []
    private(set) var memoDraft: MemoDraft?
    /// 健診後メモ（と書きかけ）の写真を、メモの ID ごとにまとめたもの（段階 E）。それぞれ並び順。
    private(set) var photosByMemoID: [UUID: [MemoPhoto]] = [:]
    /// 書きかけの新しい質問（R-72）。
    private(set) var questionDraft: QuestionDraft?
    /// 次の健診。日付が入っていなければ `nil`。
    private(set) var nextCheckup: NextCheckup?
    /// 持ち物の品目（R-34）。
    private(set) var bringItems: [BringItem] = []
    /// 出産予定日。入れていなければ `nil`。
    private(set) var dueDate: CalendarDay?
    /// 「妊娠週数を表示する」（R-53）。
    private(set) var showsGestationalAge = true
    /// 「はじめに」を出すか。初めて開いたときだけ出す。
    private(set) var needsOnboarding = false
    /// 「元に戻す」を出すかどうか。窓口の値を写したもの。
    private(set) var pendingUndo: PendingUndo?
    /// 画面に出すエラーの文。出し終えたら画面が `nil` に戻す。
    var errorMessage: String?
    /// 次の健診のお知らせを、データに合わせる係（段階 C）。操作のたびに合わせるよう頼む。
    var reminders: ReminderSync?

    @ObservationIgnored private let service: NoteService
    /// 保存場所。窓口が使っている間、閉じないように持っておく。
    @ObservationIgnored private let container: ModelContainer
    /// 元に戻すの帯を出しておく長さ（R-60、目安 6 秒）。テストでは短くする。
    @ObservationIgnored private let undoDisplayDuration: Duration
    /// 帯を時間で消すための待ち。新しい「元に戻す」ができたら、待ち直す。
    @ObservationIgnored private var undoExpiry: Task<Void, Never>?

    init(container: ModelContainer, service: NoteService, undoDisplayDuration: Duration = .seconds(6)) {
        self.container = container
        self.service = service
        self.undoDisplayDuration = undoDisplayDuration
        reload()
    }

    /// 窓口の操作を 1 つ呼ぶ。失敗したらエラーの文を出し、`nil` を返す。
    ///
    /// - Parameter saveFailureMessage: 保存に失敗したときの文を、場面に合わせて変えたいときに渡す。
    ///   例：書き始めるだけで、まだ何も入力していないときに「入力した内容はそのままです」と出さないため。
    @discardableResult
    func perform<Value>(saveFailureMessage: String? = nil, _ operation: (NoteService) throws -> Value) -> Value? {
        defer {
            reload()
            // データを先に保存し、そのあとでお知らせを合わせる（S-05）。保存に失敗したときはデータが変わっていないので、合わせても何も変わらない。
            reminders?.requestSync()
        }
        do {
            return try operation(service)
        } catch NoteServiceError.saveFailed {
            errorMessage = saveFailureMessage ?? NoteServiceError.saveFailed.message
            return nil
        } catch let error as NoteServiceError {
            errorMessage = error.message
            return nil
        } catch {
            errorMessage = saveFailureMessage ?? NoteServiceError.saveFailed.message
            return nil
        }
    }

    /// 空の書きかけの健診後メモを消す（段階 F）。シートを閉じたときに呼ぶ。書きかけがなければ何もしない。
    func discardEmptyMemoDraft() {
        guard memoDraft != nil else {
            return
        }
        perform { try $0.discardMemoDraftIfEmpty() }
    }

    /// 保存場所から読み直す。
    func reload() {
        do {
            questions = try service.questions()
            memos = try service.memos()
            memoDraft = try service.memoDraft()
            photosByMemoID = Dictionary(grouping: try service.allPhotos(), by: \.memoID)
            questionDraft = try service.questionDraft()
            nextCheckup = try service.nextCheckup()
            bringItems = try service.bringItems()
            let profile = try service.profile()
            dueDate = profile?.dueDateNumber.flatMap { CalendarDay(number: $0) }
            showsGestationalAge = profile?.showsGestationalAge ?? true
            needsOnboarding = profile.map { !$0.hasFinishedOnboarding } ?? false
        } catch {
            errorMessage = "データを読み込めませんでした。"
        }
        let latestUndo = service.pendingUndo
        if latestUndo != pendingUndo {
            pendingUndo = latestUndo
            scheduleUndoExpiry()
        }
    }

    /// そのメモ（または書きかけ）の写真。並び順。
    func photos(forMemo id: UUID) -> [MemoPhoto] {
        photosByMemoID[id] ?? []
    }

    /// 書きかけの健診後メモに選んだ写真。並び順。
    var memoDraftPhotos: [MemoPhoto] {
        memoDraft.map { photos(forMemo: $0.id) } ?? []
    }

    /// お知らせを考えるのに要る、いまの「次の健診」の値。予定がなければ `nil`。
    var reminderInput: ReminderInput? {
        guard let next = nextCheckup, let day = next.day else {
            return nil
        }
        return ReminderInput(checkupDay: day, slot: next.reminderSlot, isOn: next.isReminderOn)
    }

    /// その日の妊娠週数の文（今日・次の健診・目安の日付に使う。R-51）。出さないときは `nil`。
    func gestationalAgeText(on day: CalendarDay) -> String? {
        GestationalAgeDisplay.text(on: day, dueDate: dueDate, isShown: showsGestationalAge)
    }

    /// 元に戻すの帯を、決まった時間のあとに消す（R-60）。
    ///
    /// 消すときは窓口の「元に戻す」もやめる。帯が消えたあとに戻せると、何が戻るのかわからなくなるため。
    /// 保存に失敗した操作では「元に戻す」は変わらないので、待ちもそのまま続く。
    private func scheduleUndoExpiry() {
        undoExpiry?.cancel()
        guard let undo = pendingUndo else {
            return
        }
        let duration = undoDisplayDuration
        undoExpiry = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else {
                return
            }
            self?.expireUndo(undo)
        }
    }

    private func expireUndo(_ undo: PendingUndo) {
        // 待っている間に別の操作をしていたら、その新しい「元に戻す」は消さない。
        guard service.pendingUndo == undo else {
            return
        }
        service.discardUndo()
        pendingUndo = nil
    }
}

extension NoteServiceError {
    /// 画面に出す文。
    var message: String {
        switch self {
        case .emptyText:
            "文が空です。"
        case .emptyMemo:
            "本文・「この健診で聞いたこと」・写真のどれかを入れてください。"
        case .tooManyPhotos:
            "写真は 1 つのメモに \(NoteService.maxPhotosPerMemo) 枚までです。"
        case .notFound:
            "見つかりませんでした。画面を開き直してください。"
        case .saveFailed:
            "保存できませんでした。入力した内容はそのままです。もう一度試してください。"
        case .nothingToUndo:
            "元に戻せる操作はありません。"
        }
    }
}
