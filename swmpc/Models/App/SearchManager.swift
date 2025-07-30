//
//  SearchManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/07/2025.
//

import SwiftUI

@Observable
final class SearchManager {
    enum SearchField: String, CaseIterable, Identifiable {
        case title = "Title"
        case artist = "Artist"
        case album = "Album"
        case genre = "Genre"
        
        var id: String { rawValue }
        
        var systemImage: Image {
            switch self {
            case .title: Image(systemName: "music.note")
            case .artist: Image(systemName: "person")
            case .album: Image(systemName: "square.stack")
            case .genre: Image(systemName: "guitars")
            }
        }
    }
    
    var enabledFields: Set<SearchField> = MediaType.album.defaultSearchFields
    
    /// Applies the default search fields for the given media type.
    func applyDefaults(for mediaType: MediaType) {
        enabledFields = mediaType.defaultSearchFields
    }
    
    func filter(_ media: [any Mediable], query: String) -> [any Mediable] {
        guard !query.isEmpty else { return media }
        
        return media.filter { item in
            guard let searchableItem = item as? Searchable else { return false }
            
            return enabledFields.contains { field in
                if let fieldValue = searchableItem.search(for: field) {
                    return fieldValue.localizedCaseInsensitiveContains(query)
                }
                return false
            }
        }
    }
    
    
    func toggle(_ field: SearchField) {
        enabledFields.formSymmetricDifference([field])
    }
}
