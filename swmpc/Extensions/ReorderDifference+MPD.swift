//
//  ReorderDifference+MPD.swift
//  swmpc
//
//  Created by Camille Scholtz on 20/07/2026.
//

import MPDKit
import SwiftUI

extension ReorderDifference where ItemID == Song.ID,
    CollectionID == ReorderableSingleCollectionIdentifier
{
    /// Sends this reorder to MPD as a single-song move.
    ///
    /// The reorderable lists don't support multi-item drags, so only the
    /// first moved song is handled, matching MPD's single-song move command.
    ///
    /// - Parameters:
    ///   - songs: The songs as currently displayed, used to resolve the moved
    ///            song and its destination index.
    ///   - source: The source (either `.queue` or a `.playlist`) where the
    ///             move should occur.
    func perform(on songs: [Song], in source: Source) async {
        guard let id = sources.first,
              let song = songs.first(where: { $0.id == id })
        else {
            return
        }

        let remaining = songs.filter { $0.id != id }
        let index = switch destination.position {
        case let .before(beforeID):
            remaining.firstIndex { $0.id == beforeID } ?? remaining.endIndex
        case .end:
            remaining.endIndex
        }

        try? await ConnectionManager.command {
            try await $0.move(song, to: index, in: source)
        }
    }
}
