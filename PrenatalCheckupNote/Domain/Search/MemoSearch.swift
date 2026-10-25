import Foundation

/// これまでの健診の検索（要件定義 v0.4 の 4 章「これまでの健診」、段階 D の決まり）。画面や保存の仕組みから切り離して、テストで確かめる。
///
/// - 入れた言葉が含まれていれば当たる（部分一致）。ひらがなとカタカナ、全角と半角、英字の大文字と小文字は区別しない。
/// - 空白で区切った複数の言葉は、すべてを含むメモだけが当たる（言葉ごとに、別の場所に含まれていてもよい）。
/// - 探す場所は、本文・この健診で聞いた質問・その補足・先生の答え。
/// - 結果には、当たった所の前後の文（抜き出し）を添え、当たった言葉に印を付ける。
nonisolated enum MemoSearch {
    /// 探す相手の 1 件（健診後メモ 1 件）。
    nonisolated struct Document: Equatable, Sendable {
        nonisolated struct Item: Equatable, Sendable {
            let question: String
            let note: String
            let answer: String
        }

        let id: UUID
        let body: String
        /// この健診で聞いたこと（並び順）。
        let items: [Item]
    }

    /// 当たったメモ 1 件。
    nonisolated struct Result: Equatable, Sendable {
        let id: UUID
        /// 当たった所の前後の文。
        let snippet: Snippet
    }

    /// 抜き出しの文。どこから抜き出したかと、印を付ける所で区切った文。
    nonisolated struct Snippet: Equatable, Sendable {
        /// どこから抜き出したか。本文なら `nil`、それ以外は「質問」「補足」「先生の答え」。
        let label: String?
        let pieces: [Piece]

        /// 区切った文の 1 つ。`isMatch` なら、当たった言葉。
        nonisolated struct Piece: Equatable, Sendable {
            let text: String
            let isMatch: Bool
        }

        /// 印を付けずにつなげた文（テストや読み上げ用）。
        var plainText: String {
            pieces.map(\.text).joined()
        }
    }

    /// 当たった所の前に出す文字数。
    static let leadingContext = 12
    /// 当たった所の後ろに出す文字数（当たった言葉を含まない）。
    static let trailingContext = 28

    /// 入れた文を、探す言葉に分ける。空白（全角の空白も）で区切り、空の言葉は捨てる。
    static func terms(from query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// 探す。言葉が 1 つもなければ `nil`（検索していない。一覧をそのまま出す）。
    static func search(_ query: String, in documents: [Document]) -> [Result]? {
        let foldedTerms = terms(from: query).map { FoldedText($0).characters }.filter { !$0.isEmpty }
        guard !foldedTerms.isEmpty else {
            return nil
        }
        return documents.compactMap { document in
            let fields = Field.fields(of: document)
            // すべての言葉が、どこかの場所に含まれているか。
            let containsAll = foldedTerms.allSatisfy { term in
                fields.contains { !$0.folded.ranges(of: term).isEmpty }
            }
            guard containsAll else {
                return nil
            }
            // 最初に当たった場所（本文 → 質問 → 補足 → 答えの順）から抜き出す。
            for field in fields {
                let ranges = foldedTerms.flatMap { field.folded.ranges(of: $0) }
                if !ranges.isEmpty {
                    return Result(id: document.id, snippet: field.snippet(matching: ranges))
                }
            }
            return nil
        }
    }

    /// 探す場所 1 つ（本文、ある質問の文、など）。
    private nonisolated struct Field {
        let label: String?
        let folded: FoldedText

        static func fields(of document: Document) -> [Field] {
            var fields = [Field(label: nil, folded: FoldedText(document.body))]
            for item in document.items {
                fields.append(Field(label: "質問", folded: FoldedText(item.question)))
                fields.append(Field(label: "補足", folded: FoldedText(item.note)))
                fields.append(Field(label: "先生の答え", folded: FoldedText(item.answer)))
            }
            return fields
        }

        /// 当たった所（元の文の文字の位置）の前後を抜き出し、当たった言葉で区切る。
        func snippet(matching foldedRanges: [Range<Int>]) -> Snippet {
            let original = folded.original
            let matches = foldedRanges
                .map { folded.originalRange(of: $0) }
                .sorted { $0.lowerBound < $1.lowerBound }
            let first = matches[0]
            let start = max(0, first.lowerBound - MemoSearch.leadingContext)
            let end = min(original.count, first.upperBound + MemoSearch.trailingContext)

            // 抜き出す範囲の中の当たった所を、重なりをまとめて並べる。
            var marks: [Range<Int>] = []
            for match in matches {
                let clipped = max(match.lowerBound, start)..<min(match.upperBound, end)
                guard !clipped.isEmpty else {
                    continue
                }
                if let last = marks.last, clipped.lowerBound <= last.upperBound {
                    marks[marks.count - 1] = last.lowerBound..<max(last.upperBound, clipped.upperBound)
                } else {
                    marks.append(clipped)
                }
            }

            var pieces: [Snippet.Piece] = []
            func append(_ range: Range<Int>, isMatch: Bool) {
                guard !range.isEmpty else {
                    return
                }
                // 改行は空白にして、1 行で読めるようにする。
                let text = String(original[range]).map { $0.isNewline ? " " : String($0) }.joined()
                pieces.append(Snippet.Piece(text: text, isMatch: isMatch))
            }
            var position = start
            for mark in marks {
                append(position..<mark.lowerBound, isMatch: false)
                append(mark, isMatch: true)
                position = mark.upperBound
            }
            append(position..<end, isMatch: false)

            if start > 0 {
                pieces.insert(Snippet.Piece(text: "…", isMatch: false), at: 0)
            }
            if end < original.count {
                pieces.append(Snippet.Piece(text: "…", isMatch: false))
            }
            return Snippet(label: label, pieces: pieces)
        }
    }
}

/// 比べるために、区別しない違い（ひらがなとカタカナ・全角と半角・大文字と小文字）をそろえた文。
///
/// 1 文字ずつそろえ、そろえた文の位置から元の文の位置へ戻せるようにしておく（当たった言葉に印を付けるため）。
nonisolated struct FoldedText {
    /// 元の文（文字の並び）。
    let original: [Character]
    /// そろえた文（文字の並び）。
    let characters: [Character]
    /// そろえた文の各文字が、元の文の何文字目から来たか。
    private let sourceIndex: [Int]

    init(_ text: String) {
        let original = Array(text)
        var characters: [Character] = []
        var sourceIndex: [Int] = []
        for (index, character) in original.enumerated() {
            for folded in Self.fold(character) {
                characters.append(folded)
                sourceIndex.append(index)
            }
        }
        self.original = original
        self.characters = characters
        self.sourceIndex = sourceIndex
    }

    /// `term` が含まれる位置（そろえた文の中の範囲）をすべて返す。
    func ranges(of term: [Character]) -> [Range<Int>] {
        guard !term.isEmpty, term.count <= characters.count else {
            return []
        }
        var result: [Range<Int>] = []
        for start in 0...(characters.count - term.count) where characters[start..<(start + term.count)].elementsEqual(term) {
            result.append(start..<(start + term.count))
        }
        return result
    }

    /// そろえた文の範囲を、元の文の範囲に戻す。
    func originalRange(of range: Range<Int>) -> Range<Int> {
        sourceIndex[range.lowerBound]..<(sourceIndex[range.upperBound - 1] + 1)
    }

    /// 1 文字をそろえる。
    static func fold(_ character: Character) -> [Character] {
        var result = ""
        for scalar in character.unicodeScalars {
            result.unicodeScalars.append(contentsOf: fold(scalar))
        }
        return Array(result.lowercased())
    }

    private static func fold(_ scalar: Unicode.Scalar) -> [Unicode.Scalar] {
        let value = scalar.value
        switch value {
        case 0x3041...0x3096, 0x309D...0x309E:
            // ひらがな → カタカナ（「ぁ」〜「ゖ」と「ゝ」「ゞ」）。
            return [Unicode.Scalar(value + 0x60)!]
        case 0xFF01...0xFF5E:
            // 全角の英数字・記号 → 半角。
            return [Unicode.Scalar(value - 0xFEE0)!]
        case 0x3000:
            // 全角の空白 → 半角の空白。
            return [" "]
        case 0xFF61...0xFF9F:
            // 半角カタカナ → 全角カタカナ。
            let folded = String(scalar).applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? String(scalar)
            return Array(folded.unicodeScalars)
        default:
            return [scalar]
        }
    }
}
