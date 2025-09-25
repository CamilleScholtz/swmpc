//
//  Error+Equatable.swift
//  swmpc
//
//  Created by Camille Scholtz on 25/09/2025.
//

import SwiftUI

/// A wrapper for Error types that provides Equatable conformance. This allows
/// errors to be used with SwiftUI's onChange modifier.
struct EquatableError: Error, Equatable {
    let underlying: any Error

    init(_ error: any Error) {
        underlying = error
    }

    static func == (lhs: EquatableError, rhs: EquatableError) -> Bool {
        String(describing: lhs.underlying) == String(describing: rhs.underlying)
    }

    var localizedDescription: String {
        underlying.localizedDescription
    }
}

// Extension to make optional errors equatable for onChange.
extension EquatableError? {
    static func == (lhs: EquatableError?, rhs: EquatableError?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            true
        case let (.some(lhsError), .some(rhsError)):
            lhsError == rhsError
        default:
            false
        }
    }
}
