//
//  SearchManager.swift
//  swmpc
//
//  Created by Cmaille Scholtz on 29/07/2025.
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
        
        let lowercasedQuery = query.lowercased()
        
        return media.filter { item in
            switch item {
            case let album as Album:
                return matchesAlbum(album, query: lowercasedQuery)
            case let artist as Artist:
                return matchesArtist(artist, query: lowercasedQuery)
            case let song as Song:
                return matchesSong(song, query: lowercasedQuery)
            default:
                return false
            }
        }
    }
    
    private func matchesAlbum(_ album: Album, query: String) -> Bool {
        var matches = false
        
        if enabledFields.contains(.title) {
            matches = matches || album.title.lowercased().contains(query)
        }
        
        if enabledFields.contains(.artist) {
            matches = matches || album.artist.name.lowercased().contains(query)
        }
        
        if enabledFields.contains(.genre), let genre = album.genre {
            matches = matches || genre.lowercased().contains(query)
        }
        
        return matches
    }
    
    private func matchesArtist(_ artist: Artist, query: String) -> Bool {
        enabledFields.contains(.artist) && artist.name.lowercased().contains(query)
    }
    
    private func matchesSong(_ song: Song, query: String) -> Bool {
        var matches = false
        
        if enabledFields.contains(.title) {
            matches = matches || song.title.lowercased().contains(query)
        }
        
        if enabledFields.contains(.artist) {
            matches = matches || song.artist.lowercased().contains(query)
        }
        
        if enabledFields.contains(.album) {
            matches = matches || song.album.title.lowercased().contains(query)
        }
        
        if enabledFields.contains(.genre), let genre = song.genre {
            matches = matches || genre.lowercased().contains(query)
        }
        
        return matches
    }
    
    func toggle(_ field: SearchField) {
        if enabledFields.contains(field) {
            enabledFields.remove(field)
        } else {
            enabledFields.insert(field)
        }
    }
}
