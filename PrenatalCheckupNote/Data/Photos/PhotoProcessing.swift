import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 保存する形にした写真 1 枚。大きく見る画像と、一覧に並べる小さい画像。
nonisolated struct PreparedPhoto: Equatable, Sendable {
    let imageData: Data
    let thumbnailData: Data
}

/// 写真を読み込めなかった（R-85）。
nonisolated struct PhotoUnreadableError: Error, Equatable {}

/// 選んだ写真を、アプリに保存する形にする（段階 E の決まり、R-82、R-83）。
///
/// - 大きく見る画像：長い辺を 2,400 ピクセルまでに縮める。エコー写真の文字や数字が読める大きさを保つ。
/// - 小さい画像：長い辺 300 ピクセル。一覧に並べるときに、大きい画像を読み込まずに済むように。
/// - どちらも JPEG にする。写真の向き（縦横）は、画像の中の情報に合わせて正しく直す。
///
/// 画像を丸ごと広げずに、縮めながら読む（`CGImageSourceCreateThumbnailAtIndex`）。大きい写真でもメモリを使いすぎないため。
nonisolated enum PhotoProcessing {
    /// 大きく見る画像の、長い辺の最大。
    static let maxPixelSize = 2_400
    /// 小さい画像の、長い辺。
    static let thumbnailPixelSize = 300
    /// JPEG の画質（0〜1）。
    static let compressionQuality = 0.85

    /// 写真のデータ（HEIC・JPEG・PNG など、iPhone が読めるもの）を、保存する形にする。読めなければ `PhotoUnreadableError`。
    static func prepare(_ data: Data) throws -> PreparedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw PhotoUnreadableError()
        }
        return PreparedPhoto(
            imageData: try jpeg(from: source, maxPixelSize: maxPixelSize),
            thumbnailData: try jpeg(from: source, maxPixelSize: thumbnailPixelSize)
        )
    }

    /// 長い辺を `maxPixelSize` までに縮めた JPEG を作る。元が小さければ、大きくはしない。
    private static func jpeg(from source: CGImageSource, maxPixelSize: Int) throws -> Data {
        let options: [CFString: Any] = [
            // 画像の中に小さい版が入っていても使わず、元の画像から作る（ぼやけた画像にしないため）。
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // 写真の向きの情報に合わせて回す。
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PhotoUnreadableError()
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoUnreadableError()
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw PhotoUnreadableError()
        }
        return output as Data
    }
}
