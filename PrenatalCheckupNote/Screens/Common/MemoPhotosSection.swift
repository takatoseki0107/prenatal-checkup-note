import PhotosUI
import SwiftUI

/// 健診後メモの写真の欄（段階 E、R-80〜R-85）。書くシートと、過去のメモを直す画面の両方で使う。
///
/// 小さい画像を横に並べ、× で 1 枚ずつ外せる（元に戻せる）。「写真を足す」で残りの枚数まで選べる。
/// 選んだ写真は、画面のスレッドとは別のところで縮めてから、すぐ保存する。読み込めなかった写真は数を知らせる。
struct MemoPhotosSection: View {
    @Environment(NoteStore.self) private var store

    /// 写真の持ち主（書きかけ、または保存したメモ）の ID。まだなければ `nil`（足せない）。
    let memoID: UUID?
    /// いまの写真。並び順。
    let photos: [MemoPhoto]
    /// 読み込んでいる写真の数。呼び出し側は、0 でない間は保存できないようにする。
    @Binding var loadingCount: Int
    /// 欄の下の説明。
    let footer: String

    /// 写真の選択画面で選んだもの。受け取ったら、すぐ空に戻す。
    @State private var pickedItems: [PhotosPickerItem] = []
    /// 直前に選んだ写真のうち、読み込めなかった数（R-85）。
    @State private var failedCount = 0

    var body: some View {
        Section {
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                            PhotoThumbnail(thumbnailData: photo.thumbnailData, number: offset + 1)
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        store.perform { try $0.removePhoto(id: photo.id) }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(4)
                                    .accessibilityLabel("写真 \(offset + 1) を外す")
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            if loadingCount > 0 {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("写真を読み込んでいます")
                        .foregroundStyle(.secondary)
                }
            }
            if failedCount > 0 {
                Label("\(failedCount) 枚の写真を読み込めませんでした。ほかの写真とメモはそのままです。", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            PhotosPicker(
                selection: $pickedItems,
                maxSelectionCount: max(remainingCount, 1),
                matching: .images
            ) {
                Label("写真を足す", systemImage: "photo.badge.plus")
            }
            .disabled(memoID == nil || remainingCount == 0 || loadingCount > 0)
        } header: {
            Text("写真（\(NoteService.maxPhotosPerMemo) 枚まで）")
        } footer: {
            Text(footer)
        }
        // 選んだ写真を受け取ったら、読み込んで写しを保存する。選択はすぐ空に戻し、同じ写真をもう一度選べるようにする。
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else {
                return
            }
            pickedItems = []
            Task {
                await addPhotos(items)
            }
        }
    }

    /// あと何枚足せるか。
    private var remainingCount: Int {
        max(0, NoteService.maxPhotosPerMemo - photos.count)
    }

    /// 選んだ写真を 1 枚ずつ読み込み、縮めた写しを保存する。読み込めなかった写真は数えて知らせる（R-85）。
    private func addPhotos(_ items: [PhotosPickerItem]) async {
        guard let memoID else {
            return
        }
        // 一度に足せるのは、残りの枚数まで（選択画面でも絞っている）。
        let accepted = Array(items.prefix(remainingCount))
        failedCount = 0
        loadingCount += accepted.count
        for item in accepted {
            defer {
                loadingCount -= 1
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw PhotoUnreadableError()
                }
                // 縮める処理は重いので、画面のスレッドとは別のところで行う。
                let prepared = try await PhotoProcessing.prepareInBackground(data)
                store.perform { try $0.addPhoto(prepared, memoID: memoID, now: .now) }
            } catch {
                failedCount += 1
            }
        }
    }
}
