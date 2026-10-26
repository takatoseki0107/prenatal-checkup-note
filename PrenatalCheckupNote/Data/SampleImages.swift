import UIKit

/// サンプルデータの写真（段階 F3）。紹介動画や面接で写真の機能を見せるための、見本の絵をコードで描く。
///
/// 本当の写真やエコー写真は使わない。どちらの絵にも「サンプル」と書き、本物と間違えないようにする。
/// エコー写真に似せた絵も作らない（本物と誤解されるおそれがあるため）。
/// 2 枚目は小さい文字を入れた案内の紙にして、大きく表示して拡大すると読めることを見せられるようにする。
enum SampleImages {
    /// 1 枚目：空色の地に白いカード、ハートと星の、やわらかい見本の絵（横長、1,600 × 1,200）。
    static func picture() -> Data {
        let size = CGSize(width: 1_600, height: 1_200)
        return render(size: size) { context in
            sky.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let card = CGRect(x: 160, y: 140, width: 1_280, height: 920)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: card, cornerRadius: 80).fill()

            drawSymbol("heart.fill", color: pink, in: CGRect(x: 600, y: 230, width: 400, height: 360))
            drawSymbol("star.fill", color: yellow, in: CGRect(x: 360, y: 270, width: 150, height: 150))
            drawSymbol("star.fill", color: yellow, in: CGRect(x: 1_110, y: 440, width: 110, height: 110))
            drawSymbol("sparkle", color: accent, in: CGRect(x: 1_110, y: 250, width: 130, height: 130))

            drawText("サンプルの写真", size: 120, color: ink, in: CGRect(x: card.minX, y: 650, width: card.width, height: 170))
            drawText("アプリの見本の絵です。本物の写真ではありません。", size: 48, color: subInk,
                     in: CGRect(x: card.minX, y: 860, width: card.width, height: 80))
        }
    }

    /// 2 枚目：病院でもらう案内の紙のような見本の絵（縦長、1,200 × 1,600）。中身はすべて架空のもの。
    static func handout() -> Data {
        let size = CGSize(width: 1_200, height: 1_600)
        return render(size: size) { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // 上の帯と題名。
            sky.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: 220))
            drawText("母親学級のご案内", size: 76, color: ink, in: CGRect(x: 100, y: 70, width: 1_000, height: 110), alignment: .left)

            // 右上の「サンプル」の札。
            let tag = CGRect(x: 860, y: 270, width: 260, height: 96)
            pink.setFill()
            UIBezierPath(roundedRect: tag, cornerRadius: 48).fill()
            drawText("サンプル", size: 46, color: .white, in: tag.insetBy(dx: 0, dy: 20))

            // 中身（架空）。
            let rows: [(label: String, value: String)] = [
                ("日時", "毎月 第 2 土曜日　10:00〜11:30"),
                ("場所", "2 階　会議室"),
                ("内容", "お産の流れ／赤ちゃんのお風呂の練習"),
                ("持ち物", "母子健康手帳・筆記用具"),
                ("申し込み", "受付でお申し出ください"),
            ]
            var y: CGFloat = 430
            for row in rows {
                drawText(row.label, size: 40, color: accent, in: CGRect(x: 100, y: y, width: 260, height: 70), alignment: .left)
                drawText(row.value, size: 40, color: ink, in: CGRect(x: 360, y: y, width: 760, height: 70), alignment: .left)
                subInk.withAlphaComponent(0.3).setFill()
                context.fill(CGRect(x: 100, y: y + 90, width: 1_000, height: 2))
                y += 130
            }

            // いちばん下の小さい文字。大きく表示して拡大すると読める大きさにする。
            drawText(
                "※ この画像はアプリ「妊婦健診ノート」の見本です。実在の病院・教室の案内ではありません。\n"
                    + "※ 健診後メモに写真を付けると、押して大きく表示し、指で広げて拡大できます。",
                size: 28,
                color: subInk,
                in: CGRect(x: 100, y: 1_300, width: 1_000, height: 220),
                alignment: .left
            )
        }
    }

    // MARK: - 色（AppColors と同じ空色系。絵の中なのでライトとダークで変えない）

    private static let sky = rgb(0xE4F2FB)
    private static let accent = rgb(0x447AB0)
    private static let ink = rgb(0x33475F)
    private static let subInk = rgb(0x56687D)
    private static let pink = rgb(0xE7849B)
    private static let yellow = rgb(0xF0B429)

    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    // MARK: - 描く道具

    /// 指定した大きさ（ピクセル）の絵を描いて、PNG のデータにする。
    private static func render(size: CGSize, draw: (UIGraphicsImageRendererContext) -> Void) -> Data {
        let format = UIGraphicsImageRendererFormat()
        // 画面の倍率によらず、指定したピクセル数で描く。
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            draw(context)
        }
    }

    /// iPhone の記号（SF Symbols）を、縦横の比を保って枠の中に描く。
    private static func drawSymbol(_ name: String, color: UIColor, in rect: CGRect) {
        let configuration = UIImage.SymbolConfiguration(pointSize: rect.height)
        guard let image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else {
            return
        }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        ))
    }

    /// 文字を枠の中に描く。アプリと同じ丸い字体（なければ標準の字体）。
    private static func drawText(_ text: String, size: CGFloat, color: UIColor, in rect: CGRect, alignment: NSTextAlignment = .center) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = size * 0.4
        let font = UIFont(name: AppFonts.maruName, size: size) ?? .systemFont(ofSize: size)
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }
}
