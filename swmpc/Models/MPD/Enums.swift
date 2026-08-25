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
    /// The fields to match a media type against, dropping any whose tag the
    /// server is too old to send, and falling back to the type's defaults
    /// when nothing usable is left, which would otherwise match nothing at
    /// all.
    ///
    /// - Parameters:
    ///   - type: The media type the fields belong to.
    ///   - state: The connection state, consulted for the server's protocol
    ///            version.
    /// - Returns: The fields to search.
    func resolved(for type: MediaType, on state: StateManager) -> SearchFields {
        let usable = Source.database.availableSearchFields(for: type)
            .filter { contains($0) }
            .filter { state.supports(minimumVersion: $0.minimumVersion) }

        guard !usable.isEmpty else {
            return Source.database.defaultSearchFields(for: type)
        }

        return SearchFields(fields: Set(usable))
    }
}

extension MPDKit.SortDescriptor {
    /// The descriptor to sort by, falling back to the default when the server
    /// is too old for the tag this one sorts on.
    ///
    /// Without this a stored option the server cannot honour would leave the
    /// list in database order with nothing to explain why.
    ///
    /// - Parameter state: The connection state, consulted for the server's
    ///                    protocol version.
    /// - Returns: The descriptor to sort by.
    func resolved(on state: StateManager) -> MPDKit.SortDescriptor {
        state.supports(minimumVersion: option.minimumVersion) ? self : .default
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
