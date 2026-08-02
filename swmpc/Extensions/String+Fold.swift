//
//  String+Fold.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import Foundation

extension String {
    /// The string normalized for case- and diacritic-insensitive matching.
    nonisolated var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
