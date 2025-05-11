//
//  String+Initials.swift
//  swmpc
//
//  Created by Camille Scholtz on 11/05/2025.
//

extension String {
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
            let first = words.first!.first!
            let last = words.last!.first!

            return String([first, last]).uppercased()
        }
    }
}
