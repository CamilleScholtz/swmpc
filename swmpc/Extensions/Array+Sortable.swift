//
//  Array+Sortable.swift
//  swmpc
//
//  Created by Camille Scholtz on 30/07/2025.
//

import SwiftUI

extension ComparisonResult {
    /// If the current result is `.orderedSame`, it returns the next comparison.
    /// Otherwise, it returns itself.
    ///
    /// Usage:
    /// ```
    /// let result = primaryComparison.then(secondaryComparison)
    /// ```
    nonisolated func then(_ nextComparison: @autoclosure () -> ComparisonResult) -> ComparisonResult {
        return self == .orderedSame ? nextComparison() : self
    }

    /// A convenience for comparing numbers (like track or disc number).
    nonisolated func then<T: Comparable>(_ lhs: T, isLessThan rhs: T) -> ComparisonResult {
        if self != .orderedSame { return self }
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }
}
