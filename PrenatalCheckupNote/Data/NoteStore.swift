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
    /// 「元に戻す」を出すかどうか。窓口の値を写したもの。
    private(set) var pendingUndo: PendingUndo?
    /// 画面に出すエラーの文。出し終えたら画面が `nil` に戻す。
    var errorMessage: String?

    @ObservationIgnored private let service: NoteService
    /// 保存場所。窓口が使っている間、閉じないように持っておく。
    @ObservationIgnored private let container: ModelContainer

    init(container: ModelContainer, service: NoteService) {
        self.container = container
        self.service = service
        reload()
    }

    /// 窓口の操作を 1 つ呼ぶ。失敗したらエラーの文を出し、`nil` を返す。
    @discardableResult
    func perform<Value>(_ operation: (NoteService) throws -> Value) -> Value? {
        defer { reload() }
        do {
            return try operation(service)
        } catch let error as NoteServiceError {
            errorMessage = error.message
            return nil
        } catch {
            errorMessage = NoteServiceError.saveFailed.message
            return nil
        }
    }

    /// 保存場所から読み直す。
    func reload() {
        do {
            questions = try service.questions()
            memos = try service.memos()
            memoDraft = try service.memoDraft()
        } catch {
            errorMessage = "データを読み込めませんでした。"
        }
        pendingUndo = service.pendingUndo
    }
}

extension NoteServiceError {
    /// 画面に出す文。
    var message: String {
        switch self {
        case .emptyText:
            "文が空です。"
        case .emptyMemo:
            "本文か「この健診で聞いたこと」を入れてください。"
        case .notFound:
            "見つかりませんでした。画面を開き直してください。"
        case .saveFailed:
            "保存できませんでした。入力した内容はそのままです。もう一度試してください。"
        case .nothingToUndo:
            "元に戻せる操作はありません。"
        }
    }
}
