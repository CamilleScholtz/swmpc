//
//  Enums.swift
//  swmpc
//
//  App-specific extensions for shared MPD types.
//

import MPDKit
import SFSafeSymbols

extension SearchField {
    /// Returns the SF Symbol icon associated with this search field.
    var symbol: SFSymbol {
        switch self {
        case .title:
            .textformatCharacters
        case .artist:
            .person
        case .album:
            .squareStack
        case .genre:
            .musicNote
        case .composer:
            .musicNoteList
        case .performer:
            .musicMicrophone
        case .conductor:
            .wandAndSparkles
        case .ensemble:
            .person2
        case .mood:
            .faceSmiling
        case .comment:
            .textBubble
        }
    }
}
