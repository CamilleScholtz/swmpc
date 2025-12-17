//
//  Enums.swift
//  swmpc
//
//  Created by Camille Scholtz on 10/11/2024.
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

/// The current state of the streaming player.
enum StreamState: Equatable {
    /// No stream is playing.
    case stopped
    /// Connecting to or buffering the stream.
    case loading
    /// Actively playing audio.
    case playing
    /// An error occurred.
    case error(String)
}
