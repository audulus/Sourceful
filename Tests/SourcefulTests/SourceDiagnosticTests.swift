import XCTest
@testable import Sourceful

final class SourceDiagnosticTests: XCTestCase {

    private func makeView(_ text: String, diagnostics: [SourceDiagnostic]) -> SyntaxTextView {
        let view = SyntaxTextView()
        view.theme = DefaultSourceCodeTheme()
        // The public `text` setter is deferred to the run loop on iOS, so
        // set the inner view's text directly to keep the tests synchronous.
        view.contentTextView.text = text
        view.diagnostics = diagnostics
        return view
    }

    private func replace(_ view: SyntaxTextView, _ range: NSRange, with string: String) {
        #if os(macOS)
        view.contentTextView.textStorage!.replaceCharacters(in: range, with: string)
        #else
        view.contentTextView.textStorage.replaceCharacters(in: range, with: string)
        #endif
    }

    func testParagraphBreakCountMatchesGutterNumbering() {
        // NSString paragraph breaks are \n, \r, \r\n and U+2029; U+2028 and
        // U+0085 are line separators and do not start a new gutter line.
        let s = "a\nb\r\nc\rd\u{2028}e\u{2029}f\u{85}g" as NSString
        XCTAssertEqual(s.paragraphBreakCount(in: NSRange(location: 0, length: s.length)), 4)
        XCTAssertEqual(("abc" as NSString).paragraphBreakCount(in: NSRange(location: 0, length: 3)), 0)
        XCTAssertEqual(("abc\n" as NSString).paragraphBreakCount(in: NSRange(location: 0, length: 4)), 1)
        XCTAssertEqual(("" as NSString).paragraphBreakCount(in: NSRange(location: 0, length: 0)), 0)
    }

    func testInsertingLineAboveShiftsDiagnosticDown() {
        let view = makeView("one\ntwo\nthree", diagnostics: [SourceDiagnostic(line: 3, message: "x")])
        replace(view, NSRange(location: 0, length: 0), with: "zero\n")
        XCTAssertEqual(view.diagnostics.map { $0.line }, [4])
    }

    func testDeletingLineAboveShiftsDiagnosticUp() {
        let view = makeView("one\ntwo\nthree", diagnostics: [SourceDiagnostic(line: 3, message: "x")])
        replace(view, NSRange(location: 0, length: 4), with: "")
        XCTAssertEqual(view.diagnostics.map { $0.line }, [2])
    }

    func testEditingBelowLeavesDiagnosticAlone() {
        let view = makeView("one\ntwo\nthree", diagnostics: [SourceDiagnostic(line: 1, message: "x")])
        replace(view, NSRange(location: 8, length: 5), with: "3\n4\n5")
        XCTAssertEqual(view.diagnostics.map { $0.line }, [1])
    }

    func testEditingWithinLineLeavesDiagnosticAlone() {
        let view = makeView("one\ntwo\nthree", diagnostics: [SourceDiagnostic(line: 2, message: "x")])
        replace(view, NSRange(location: 4, length: 3), with: "TWO!")
        XCTAssertEqual(view.diagnostics.map { $0.line }, [2])
    }

    func testDeletingDiagnosticLineCollapsesOntoEditLine() {
        let view = makeView("one\ntwo\nthree\nfour", diagnostics: [SourceDiagnostic(line: 2, message: "x"), SourceDiagnostic(line: 4, message: "y")])
        // Delete "\ntwo\nthree" so lines 2 and 3 merge into line 1.
        replace(view, NSRange(location: 3, length: 10), with: "")
        XCTAssertEqual(view.diagnostics.map { $0.line }, [1, 2])
    }

    func testSettingDiagnosticsReplacesShiftedOnes() {
        let view = makeView("one\ntwo", diagnostics: [SourceDiagnostic(line: 2, message: "x")])
        replace(view, NSRange(location: 0, length: 0), with: "\n")
        XCTAssertEqual(view.diagnostics.map { $0.line }, [3])
        view.diagnostics = [SourceDiagnostic(line: 1, message: "y")]
        XCTAssertEqual(view.diagnostics.map { $0.line }, [1])
    }

    func testGutterHitTestUsesParagraphRects() {
        let view = makeView("one\ntwo\nthree", diagnostics: [])
        view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        #if os(macOS)
        view.layoutSubtreeIfNeeded()
        #else
        view.layoutIfNeeded()
        #endif
        let textView = view.contentTextView as! InnerTextView
        let paragraphs = textView.paragraphs()
        XCTAssertEqual(paragraphs.map { $0.number }, [1, 2, 3])
        for p in paragraphs {
            let hit = textView.line(at: CGPoint(x: 1, y: p.rect.midY))
            XCTAssertEqual(hit?.line, p.number)
            XCTAssertEqual(hit?.lineRect.minY, p.rect.minY)
        }
        // Outside the gutter is never a hit.
        XCTAssertNil(textView.line(at: CGPoint(x: textView.gutterWidth + 1, y: paragraphs[0].rect.midY)))
    }

    func testEmptyTextStillHasClickableLineOne() {
        let view = makeView("", diagnostics: [SourceDiagnostic(line: 1, message: "x")])
        view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        let textView = view.contentTextView as! InnerTextView
        let rect = textView.paragraphs()[0].rect
        XCTAssertEqual(textView.line(at: CGPoint(x: 1, y: rect.midY))?.line, 1)
    }
}
