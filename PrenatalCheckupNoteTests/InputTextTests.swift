import Testing
@testable import PrenatalCheckupNote

/// 入力された文の扱い（R-12）を確かめる。
struct InputTextTests {
    @Test(arguments: ["", "   ", "\n\n", " \n\t ", "\u{3000}\u{3000}"])
    func treatsBlankTextAsEmpty(text: String) {
        #expect(InputText.normalized(text) == nil)
    }

    @Test func trimsOnlyTheEnds() {
        #expect(InputText.normalized("  腰の痛みについて相談する \n") == "腰の痛みについて相談する")
        #expect(InputText.normalized("\u{3000}1 行目\n2 行目\u{3000}") == "1 行目\n2 行目")
    }
}
