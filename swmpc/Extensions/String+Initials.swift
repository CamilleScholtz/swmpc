//
//  String+Initials.swift
//  swmpc
//
//  Created by Camille Scholtz on 11/05/2025.
//

extension String {
    /// Generates initials from the string.
    ///
    /// For single words, uses the first and last characters. For multiple
    /// words, uses the first character of the first and last words. Returns "?"
    /// for empty strings or strings with no valid characters.
    ///
    /// - Returns: A 2-character uppercase string representing the initials.
    var initials: String {
        let words = components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        switch words.count {
        case 0: return "?"
        case 1:
            let s = words[0]
            guard let first = s.first, let last = s.last else {
                return "?"
            }

            return String([first, last]).uppercased()
        default:
            guard let first = words.first?.first,
                  let last = words.last?.first
            else {
                return "?"
            }

            return String([first, last]).uppercased()
        }
    }
}
