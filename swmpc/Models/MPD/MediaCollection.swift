//
//  MediaCollection.swift
//  swmpc
//
//  Created by Camille Scholtz on 21/08/2026.
//

import MPDKit

/// A loaded collection of media, kept in its concrete element type.
///
/// The library lists hold tens of thousands of items, so storing them as
/// `[any Mediable]` would box every element on the heap and force the list to
/// downcast the whole array back before it can build rows. Keeping the
/// element type in the case avoids both.
enum MediaCollection: Sendable {
    case albums([Album])
    case artists([Artist])
    case songs([Song])

    /// The media type of the items in this collection.
    var type: MediaType {
        switch self {
        case .albums: .album
        case .artists: .artist
        case .songs: .song
        }
    }

    /// The number of items in this collection.
    var count: Int {
        switch self {
        case let .albums(albums): albums.count
        case let .artists(artists): artists.count
        case let .songs(songs): songs.count
        }
    }

    /// Indicates whether this collection holds no items.
    var isEmpty: Bool {
        count == 0
    }

    /// The identifier of the item at a given position.
    ///
    /// - Parameter index: The position of the item.
    /// - Returns: The item's identifier, or `nil` if the position is out of
    ///            bounds.
    func id(at index: Int) -> String? {
        guard index >= 0, index < count else {
            return nil
        }

        return switch self {
        case let .albums(albums): albums[index].id
        case let .artists(artists): artists[index].id
        case let .songs(songs): songs[index].id
        }
    }
}
