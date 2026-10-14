//
//  InnerTextView.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 09/07/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import Foundation
import CoreGraphics

#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

protocol InnerTextViewDelegate: AnyObject {
	func didUpdateCursorFloatingState()

	/// Called when the gutter is clicked or tapped. `lineRect` is the
	/// line's gutter cell in the text view's coordinate space.
	/// Return true to consume the event.
	func didSelectGutterLine(_ line: Int, lineRect: CGRect) -> Bool
}

class InnerTextView: TextView {

	weak var innerDelegate: InnerTextViewDelegate?

	var theme: SyntaxColorTheme?

	var cachedParagraphs: [Paragraph]?

	func invalidateCachedParagraphs() {
		cachedParagraphs = nil
	}

	var diagnostics: [SourceDiagnostic] = [] {
		didSet {
			diagnosticsByLine = Dictionary(grouping: diagnostics, by: { $0.line })
		}
	}

	/// Diagnostics grouped by 1-based line number.
	private(set) var diagnosticsByLine: [Int: [SourceDiagnostic]] = [:]

	var diagnosticColor: Color = .systemRed

	func diagnostics(onLine line: Int) -> [SourceDiagnostic] {
		diagnosticsByLine[line] ?? []
	}

	/// Paragraph rects in this view's coordinate space, cached until the
	/// text or layout changes. This is the single source of truth for which
	/// line sits at a given y, used by both drawing and hit-testing.
	func paragraphs() -> [Paragraph] {
		if let cached = cachedParagraphs {
			return cached
		}
		let paragraphs = generateParagraphs(for: self)
		cachedParagraphs = paragraphs
		return paragraphs
	}

	/// The 1-based line under `point` (in this view's coordinate space),
	/// and that line's gutter cell, or nil if the point is not over a line
	/// or the gutter is hidden.
	func line(at point: CGPoint) -> (line: Int, lineRect: CGRect)? {

		guard theme?.lineNumbersStyle != nil, point.x < gutterWidth else {
			return nil
		}

		guard let paragraph = paragraphs().first(where: { point.y >= $0.rect.minY && point.y < $0.rect.maxY }) else {
			return nil
		}

		let lineRect = CGRect(x: 0,
		                      y: paragraph.rect.minY,
		                      width: gutterWidth,
		                      height: paragraph.rect.height)

		return (paragraph.number, lineRect)
	}

	// MARK: - Keeping diagnostics on their lines while editing

	/// Number of paragraph breaks in the text, as the gutter counts them.
	private var paragraphBreakCount: Int?

	func textStorageDidChangeCharacters(editedRange: NSRange, changeInLength: Int) {

		let nsText = text as NSString
		let newTotal = nsText.paragraphBreakCount(in: NSRange(location: 0, length: nsText.length))

		defer { paragraphBreakCount = newTotal }

		guard let oldTotal = paragraphBreakCount, !diagnostics.isEmpty else {
			return
		}

		let added = nsText.paragraphBreakCount(in: editedRange)
		let removed = max(0, added - (newTotal - oldTotal))
		let delta = added - removed

		guard delta != 0 || removed != 0 else {
			return
		}

		let startLine = nsText.paragraphBreakCount(in: NSRange(location: 0, length: editedRange.location)) + 1
		let endLine = startLine + removed

		diagnostics = diagnostics.map { diagnostic in
			var diagnostic = diagnostic
			if diagnostic.line > endLine {
				diagnostic.line += delta
			} else if diagnostic.line > startLine {
				// The line was merged into, or replaced by, the end of the edit.
				diagnostic.line = startLine + added
			}
			return diagnostic
		}
	}

	#if os(macOS)

	override func mouseDown(with event: NSEvent) {
		let point = convert(event.locationInWindow, from: nil)
		if let hit = line(at: point),
		   innerDelegate?.didSelectGutterLine(hit.line, lineRect: hit.lineRect) == true {
			return
		}
		super.mouseDown(with: event)
	}

	#endif

	func hideGutter() {
		gutterWidth = theme?.gutterStyle.minimumWidth ?? 0.0
	}
	
	func updateGutterWidth(for numberOfCharacters: Int) {
		
		let leftInset: CGFloat = 4.0
		let rightInset: CGFloat = 4.0
		
		let charWidth: CGFloat = 10.0
		
		gutterWidth = max(theme?.gutterStyle.minimumWidth ?? 0.0, CGFloat(numberOfCharacters) * charWidth + leftInset + rightInset)
		
	}
	
	#if os(iOS)
	
	var isCursorFloating = false
	
	override func beginFloatingCursor(at point: CGPoint) {
		super.beginFloatingCursor(at: point)
		
		isCursorFloating = true
		innerDelegate?.didUpdateCursorFloatingState()

	}
	
	override func endFloatingCursor() {
		super.endFloatingCursor()
		
		isCursorFloating = false
		innerDelegate?.didUpdateCursorFloatingState()

	}
	
	override public func draw(_ rect: CGRect) {
		
		guard let theme = theme else {
			super.draw(rect)
			hideGutter()
			return
		}
		
		let textView = self

		if theme.lineNumbersStyle == nil  {

			hideGutter()

			let gutterRect = CGRect(x: 0, y: rect.minY, width: textView.gutterWidth, height: rect.height)
			let path = BezierPath(rect: gutterRect)
			path.fill()
			
		} else {
			
			let components = textView.text.components(separatedBy: .newlines)
			
			let count = components.count
			
			let maxNumberOfDigits = "\(count)".count
			
			textView.updateGutterWidth(for: maxNumberOfDigits)
            
            let paragraphs = textView.paragraphs()
			
			theme.gutterStyle.backgroundColor.setFill()
			
			let gutterRect = CGRect(x: 0, y: rect.minY, width: textView.gutterWidth, height: rect.height)
			let path = BezierPath(rect: gutterRect)
			path.fill()
			
			drawLineNumbers(paragraphs, in: rect, for: self)
			
		}
		

		super.draw(rect)

	}
	#endif
	
	var gutterWidth: CGFloat {
		set {
			
			#if os(macOS)
				textContainerInset = NSSize(width: newValue, height: 0)
			#else
				textContainerInset = UIEdgeInsets(top: 0, left: newValue, bottom: 0, right: 0)
			#endif
			
		}
		get {
			
			#if os(macOS)
				return textContainerInset.width
			#else
				return textContainerInset.left
			#endif
			
		}
	}
//	var gutterWidth: CGFloat = 0.0 {
//		didSet {
//
//			textContainer.exclusionPaths = [UIBezierPath(rect: CGRect(x: 0.0, y: 0.0, width: gutterWidth, height: .greatestFiniteMagnitude))]
//
//		}
//
//	}
	
	#if os(iOS)
	
	override func caretRect(for position: UITextPosition) -> CGRect {
		
		var superRect = super.caretRect(for: position)
		
		guard let theme = theme else {
			return superRect
		}
		
		let font = theme.font
		
		// "descender" is expressed as a negative value,
		// so to add its height you must subtract its value
		superRect.size.height = font.pointSize - font.descender
		
		return superRect
	}
	
	#endif
	
}

#if os(macOS)
typealias TextStorageEditActions = NSTextStorageEditActions
#else
typealias TextStorageEditActions = NSTextStorage.EditActions
#endif

extension InnerTextView: NSTextStorageDelegate {

	func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: TextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
		guard editedMask.contains(.editedCharacters) else {
			return
		}
		textStorageDidChangeCharacters(editedRange: editedRange, changeInLength: delta)
	}

}

extension NSString {

	/// Counts paragraph breaks (\n, \r, \r\n, U+2029) in
	/// `range`, matching how the gutter numbers lines.
	func paragraphBreakCount(in range: NSRange) -> Int {
		var count = 0
		enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, substringRange, enclosingRange, _ in
			if enclosingRange.length > substringRange.length {
				count += 1
			}
		}
		return count
	}

}
