import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PrenatalCheckupNote

/// 写真を保存する形にする処理（R-82、R-83、R-85）を確かめる。
struct PhotoProcessingTests {
    /// 指定の大きさの PNG を作る。
    private func pngImage(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output as CFMutableData, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    /// 画像の幅と高さ。
    private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        return (width, height)
    }

    @Test func shrinksALargePhotoAndMakesASmallOne() throws {
        let prepared = try PhotoProcessing.prepare(try pngImage(width: 3_000, height: 2_000))

        let large = try pixelSize(of: prepared.imageData)
        #expect(large.width == 2_400)
        #expect(large.height == 1_600)

        let small = try pixelSize(of: prepared.thumbnailData)
        #expect(small.width == 300)
        #expect(small.height == 200)
    }

    @Test func doesNotEnlargeASmallPhoto() throws {
        let prepared = try PhotoProcessing.prepare(try pngImage(width: 200, height: 120))
        let large = try pixelSize(of: prepared.imageData)
        #expect(large.width == 200)
        #expect(large.height == 120)
    }

    @Test func savesAsJPEG() throws {
        let prepared = try PhotoProcessing.prepare(try pngImage(width: 400, height: 400))
        let source = try #require(CGImageSourceCreateWithData(prepared.imageData as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
    }

    @Test func refusesDataThatIsNotAPhoto() {
        #expect(throws: PhotoUnreadableError.self) {
            try PhotoProcessing.prepare(Data("写真ではない".utf8))
        }
        #expect(throws: PhotoUnreadableError.self) {
            try PhotoProcessing.prepare(Data())
        }
    }
}
