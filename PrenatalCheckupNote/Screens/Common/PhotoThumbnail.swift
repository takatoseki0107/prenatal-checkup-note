import SwiftUI
import UIKit

/// 写真 1 枚の小さい画像（段階 E）。一覧用の小さい画像（`thumbnailData`）を出す。
///
/// 画像を作れなかったときは「読み込めませんでした」と出す（R-85）。ほかの写真とメモはそのまま使える。
struct PhotoThumbnail: View {
    let thumbnailData: Data
    /// 何枚目か。読み上げに使う。
    let number: Int
    var size: CGFloat = 76

    var body: some View {
        Group {
            if let image = UIImage(data: thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("読み込めませんでした")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .padding(4)
            }
        }
        .frame(width: size, height: size)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("写真 \(number)")
    }
}
