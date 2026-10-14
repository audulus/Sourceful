//
//  SourceCodeTextEditor.swift
//
//  Created by Andrew Eades on 14/08/2020.
//

import Foundation

#if canImport(SwiftUI)

import SwiftUI

#if os(macOS)

public typealias _ViewRepresentable = NSViewRepresentable

#endif

#if os(iOS)

public typealias _ViewRepresentable = UIViewRepresentable

#endif


public struct SourceCodeTextEditor: _ViewRepresentable {
    
    public struct Customization {
        var didChangeText: (SourceCodeTextEditor) -> Void
        var insertionPointColor: () -> Sourceful.Color
        var lexerForSource: (String) -> Lexer
        var textViewDidBeginEditing: (SourceCodeTextEditor) -> Void
        var theme: () -> SourceCodeTheme
        var didSelectDiagnostics: (SourceCodeTextEditor, [SourceDiagnostic], Int, CGRect) -> Void
        
        /// Creates a **Customization** to pass into the *init()* of a **SourceCodeTextEditor**.
        ///
        /// - Parameters:
        ///     - didChangeText: A SyntaxTextView delegate action.
        ///     - lexerForSource: The lexer to use (default: SwiftLexer()).
        ///     - insertionPointColor: To customize color of insertion point caret (default: .white).
        ///     - textViewDidBeginEditing: A SyntaxTextView delegate action.
        ///     - theme: Custom theme (default: DefaultSourceCodeTheme()).
        ///     - didSelectDiagnostics: Called when the gutter beside a line with diagnostics is
        ///       clicked. Receives the line's diagnostics, the 1-based line, and the gutter cell's
        ///       rect in the editor's coordinate space (top-left origin). The reported
        ///       diagnostics may have shifted lines if the text was edited since they were set.
        public init(
            didChangeText: @escaping (SourceCodeTextEditor) -> Void,
            insertionPointColor: @escaping () -> Sourceful.Color,
            lexerForSource: @escaping (String) -> Lexer,
            textViewDidBeginEditing: @escaping (SourceCodeTextEditor) -> Void,
            theme: @escaping () -> SourceCodeTheme,
            didSelectDiagnostics: @escaping (SourceCodeTextEditor, [SourceDiagnostic], Int, CGRect) -> Void = { _, _, _, _ in }
        ) {
            self.didChangeText = didChangeText
            self.insertionPointColor = insertionPointColor
            self.lexerForSource = lexerForSource
            self.textViewDidBeginEditing = textViewDidBeginEditing
            self.theme = theme
            self.didSelectDiagnostics = didSelectDiagnostics
        }
    }
    
    @Binding private var text: String
    private var shouldBecomeFirstResponder: Bool
    private var custom: Customization
    private var diagnostics: [SourceDiagnostic]
    
    public init(
        text: Binding<String>,
        diagnostics: [SourceDiagnostic] = [],
        customization: Customization = Customization(
            didChangeText: {_ in },
            insertionPointColor: { Sourceful.Color.white },
            lexerForSource: { _ in SwiftLexer() },
            textViewDidBeginEditing: { _ in },
            theme: { DefaultSourceCodeTheme() }
        ),
        shouldBecomeFirstResponder: Bool = false
    ) {
        self._text = text
        self.diagnostics = diagnostics
        self.custom = customization
        self.shouldBecomeFirstResponder = shouldBecomeFirstResponder
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    #if os(iOS)
    public func makeUIView(context: Context) -> SyntaxTextView {
        let wrappedView = SyntaxTextView()
        wrappedView.delegate = context.coordinator
        wrappedView.theme = custom.theme()
//        wrappedView.contentTextView.insertionPointColor = custom.insertionPointColor()
        
        context.coordinator.wrappedView = wrappedView
        context.coordinator.wrappedView.text = text
        context.coordinator.apply(diagnostics, to: wrappedView)
        
        return wrappedView
    }
    
    public func updateUIView(_ view: SyntaxTextView, context: Context) {
        context.coordinator.parent = self
        if shouldBecomeFirstResponder {
            view.becomeFirstResponder()
        }
        view.text = text
        context.coordinator.apply(diagnostics, to: view)
    }
    #endif
    
    #if os(macOS)
    public func makeNSView(context: Context) -> SyntaxTextView {
        let wrappedView = SyntaxTextView()
        wrappedView.delegate = context.coordinator
        wrappedView.theme = custom.theme()
        wrappedView.contentTextView.insertionPointColor = custom.insertionPointColor()
        wrappedView.contentTextView.allowsUndo = false
        
        context.coordinator.wrappedView = wrappedView
        context.coordinator.wrappedView.text = text
        context.coordinator.apply(diagnostics, to: wrappedView)
        
        return wrappedView
    }
    
    public func updateNSView(_ view: SyntaxTextView, context: Context) {
        context.coordinator.parent = self
        view.text = text
        context.coordinator.apply(diagnostics, to: view)
    }
    #endif
    

}

extension SourceCodeTextEditor {
    
    public class Coordinator: SyntaxTextViewDelegate {
        var parent: SourceCodeTextEditor
        var wrappedView: SyntaxTextView!

        /// The host's diagnostics as last handed to the view. The view shifts
        /// its own copy as the user edits, so only push the host's array when
        /// the host actually changes it.
        private var appliedDiagnostics: [SourceDiagnostic]?

        func apply(_ diagnostics: [SourceDiagnostic], to view: SyntaxTextView) {
            guard diagnostics != appliedDiagnostics else { return }
            appliedDiagnostics = diagnostics
            view.diagnostics = diagnostics
        }
        
        init(_ parent: SourceCodeTextEditor) {
            self.parent = parent
        }
        
        public func lexerForSource(_ source: String) -> Lexer {
            parent.custom.lexerForSource(source)
        }
        
        public func didChangeText(_ syntaxTextView: SyntaxTextView) {
            self.parent.text = syntaxTextView.text

            // allow the client to decide on thread
            parent.custom.didChangeText(parent)
        }
        
        public func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView) {
            parent.custom.textViewDidBeginEditing(parent)
        }

        public func didSelectDiagnostics(_ syntaxTextView: SyntaxTextView, diagnostics: [SourceDiagnostic], line: Int, lineRect: CGRect) {
            parent.custom.didSelectDiagnostics(parent, diagnostics, line, lineRect)
        }
    }
}

#endif
