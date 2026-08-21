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

extension SearchFields {
    /// The fields to match a media type against, falling back to its
    /// defaults when the user turned all of them off, which would otherwise
    /// match nothing at all.
    ///
    /// - Parameter type: The media type the fields belong to.
    /// - Returns: The fields to search.
    func resolved(for type: MediaType) -> SearchFields {
        isEmpty ? Source.database.defaultSearchFields(for: type) : self
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
