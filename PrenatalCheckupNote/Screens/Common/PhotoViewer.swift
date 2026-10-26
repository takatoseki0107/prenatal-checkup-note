import SwiftUI
import UIKit

/// 写真を画面いっぱいに大きく出す（R-83）。左右に動かして次の写真へ。指で広げると拡大、2 回たたくと拡大・元の大きさ。
///
/// エコー写真の文字や数字を読めるように、保存した大きい画像（長い辺 2,400 ピクセルまで）を使う。
struct PhotoViewer: View {
    let photos: [MemoPhoto]
    @State var selection: UUID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                    ZoomableImage(imageData: photo.imageData, number: offset + 1)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(positionText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// 「2 / 5」のような、いま何枚目か。
    private var positionText: String {
        let index = photos.firstIndex { $0.id == selection } ?? 0
        return "\(index + 1) / \(photos.count)"
    }
}

/// 拡大できる写真 1 枚。
private struct ZoomableImage: View {
    let imageData: Data
    let number: Int

    @State private var image: UIImage?
    @State private var didFail = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// 2 回たたいたときの拡大の倍率。
    private let doubleTapScale: CGFloat = 2.5
    /// 拡大できるいちばん大きい倍率。
    private let maxScale: CGFloat = 6

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnify)
                    // 拡大しているときだけ、指でずらせる。拡大していないときは、左右の動きで次の写真へ。
                    .simultaneousGesture(DragGesture(minimumDistance: scale > 1 ? 10 : 10_000).onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }.onEnded { _ in
                        lastOffset = offset
                    })
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1 {
                                reset()
                            } else {
                                scale = doubleTapScale
                                lastScale = doubleTapScale
                            }
                        }
                    }
                    .accessibilityLabel("写真 \(number)")
                    .accessibilityHint("2 回たたくと拡大します")
            } else if didFail {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("読み込めませんでした")
                }
                .foregroundStyle(.white.opacity(0.8))
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 大きい画像は、表示するときに初めて読み込む。
        .task(id: imageData) {
            image = UIImage(data: imageData)
            didFail = image == nil
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(maxScale, max(1, lastScale * value.magnification))
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation {
                        reset()
                    }
                }
            }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
