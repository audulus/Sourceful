//
//  SourceDiagnostic.swift
//  Sourceful
//

import Foundation

/// A compiler message attached to a line of the edited source.
public struct SourceDiagnostic: Hashable, Sendable {

    /// 1-based line number in the source.
    public var line: Int

    /// 1-based column, if known.
    public var column: Int?

    public var message: String

    public init(line: Int, column: Int? = nil, message: String) {
        self.line = line
        self.column = column
        self.message = message
    }
}
