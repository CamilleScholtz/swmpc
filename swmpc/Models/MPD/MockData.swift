//
//  MockData.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/04/2025.
//

import SwiftUI

actor MockData {
    let mockArtists: [Artist] = [
        Artist(id: 1, position: 1, name: "The Beatles", albums: nil),
        Artist(id: 2, position: 2, name: "Pink Floyd", albums: nil),
        Artist(id: 3, position: 3, name: "Queen", albums: nil),
        Artist(id: 4, position: 4, name: "Led Zeppelin", albums: nil),
        Artist(id: 5, position: 5, name: "David Bowie", albums: nil)
    ]
    
    let mockAlbums: [Album] = [
        Album(id: 1, position: 1, url: URL(string: "file:///music/The%20Beatles/Abbey%20Road")!, artist: "The Beatles", title: "Abbey Road", date: "1969"),
        Album(id: 2, position: 2, url: URL(string: "file:///music/The%20Beatles/Sgt.%20Pepper")!, artist: "The Beatles", title: "Sgt. Pepper's Lonely Hearts Club Band", date: "1967"),
        Album(id: 3, position: 3, url: URL(string: "file:///music/Pink%20Floyd/Dark%20Side%20of%20the%20Moon")!, artist: "Pink Floyd", title: "The Dark Side of the Moon", date: "1973"),
        Album(id: 4, position: 4, url: URL(string: "file:///music/Pink%20Floyd/The%20Wall")!, artist: "Pink Floyd", title: "The Wall", date: "1979"),
        Album(id: 5, position: 5, url: URL(string: "file:///music/Queen/A%20Night%20at%20the%20Opera")!, artist: "Queen", title: "A Night at the Opera", date: "1975"),
        Album(id: 6, position: 6, url: URL(string: "file:///music/Led%20Zeppelin/IV")!, artist: "Led Zeppelin", title: "IV", date: "1971"),
        Album(id: 7, position: 7, url: URL(string: "file:///music/David%20Bowie/Ziggy%20Stardust")!, artist: "David Bowie", title: "The Rise and Fall of Ziggy Stardust", date: "1972")
    ]
    
    let mockSongs: [Song] = [
        Song(id: 1, position: 1, url: URL(string: "file:///music/The%20Beatles/Abbey%20Road/01%20Come%20Together.mp3")!, artist: "The Beatles", title: "Come Together", duration: 259.0, disc: 1, track: 1),
        Song(id: 2, position: 2, url: URL(string: "file:///music/The%20Beatles/Abbey%20Road/02%20Something.mp3")!, artist: "The Beatles", title: "Something", duration: 183.0, disc: 1, track: 2),
        Song(id: 3, position: 3, url: URL(string: "file:///music/The%20Beatles/Abbey%20Road/03%20Maxwell's%20Silver%20Hammer.mp3")!, artist: "The Beatles", title: "Maxwell's Silver Hammer", duration: 207.0, disc: 1, track: 3),
        Song(id: 4, position: 4, url: URL(string: "file:///music/Pink%20Floyd/Dark%20Side%20of%20the%20Moon/01%20Speak%20to%20Me.mp3")!, artist: "Pink Floyd", title: "Speak to Me", duration: 90.0, disc: 1, track: 1),
        Song(id: 5, position: 5, url: URL(string: "file:///music/Pink%20Floyd/Dark%20Side%20of%20the%20Moon/02%20Breathe.mp3")!, artist: "Pink Floyd", title: "Breathe", duration: 163.0, disc: 1, track: 2),
        Song(id: 6, position: 6, url: URL(string: "file:///music/Pink%20Floyd/Dark%20Side%20of%20the%20Moon/03%20On%20the%20Run.mp3")!, artist: "Pink Floyd", title: "On the Run", duration: 216.0, disc: 1, track: 3),
        Song(id: 7, position: 7, url: URL(string: "file:///music/Queen/A%20Night%20at%20the%20Opera/01%20Death%20on%20Two%20Legs.mp3")!, artist: "Queen", title: "Death on Two Legs", duration: 220.0, disc: 1, track: 1),
        Song(id: 8, position: 8, url: URL(string: "file:///music/Queen/A%20Night%20at%20the%20Opera/09%20Bohemian%20Rhapsody.mp3")!, artist: "Queen", title: "Bohemian Rhapsody", duration: 354.0, disc: 1, track: 9),
        Song(id: 9, position: 9, url: URL(string: "file:///music/Led%20Zeppelin/IV/01%20Black%20Dog.mp3")!, artist: "Led Zeppelin", title: "Black Dog", duration: 294.0, disc: 1, track: 1),
        Song(id: 10, position: 10, url: URL(string: "file:///music/Led%20Zeppelin/IV/04%20Stairway%20to%20Heaven.mp3")!, artist: "Led Zeppelin", title: "Stairway to Heaven", duration: 482.0, disc: 1, track: 4),
        Song(id: 11, position: 11, url: URL(string: "file:///music/David%20Bowie/Ziggy%20Stardust/01%20Five%20Years.mp3")!, artist: "David Bowie", title: "Five Years", duration: 284.0, disc: 1, track: 1),
        Song(id: 12, position: 12, url: URL(string: "file:///music/David%20Bowie/Ziggy%20Stardust/05%20Ziggy%20Stardust.mp3")!, artist: "David Bowie", title: "Ziggy Stardust", duration: 194.0, disc: 1, track: 5)
    ]
    
    let mockPlaylists: [Playlist] = [
        Playlist(name: "Favorites"),
        Playlist(name: "Rock Classics"),
        Playlist(name: "60s and 70s")
    ]
    
    var mockFavorites: [Song] {
        [mockSongs[7], mockSongs[9], mockSongs[11]]
    }
    
    private var _mockStatus: (state: PlayerState?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?, playlist: Playlist?, song: Song?) = (
        .play,
        false,
        false,
        0.0,
        nil,
        nil
    )
    
    var mockStatus: (state: PlayerState?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?, playlist: Playlist?, song: Song?) {
        get {
            if _mockStatus.state == .play {
                _mockStatus.elapsed! += 1.0
                
                if let song = _mockStatus.song, _mockStatus.elapsed! >= song.duration {
                    _mockStatus.elapsed = 0.0
                }
            }
            
            return _mockStatus
        }
        set {
            _mockStatus = newValue
        }
    }
    
    func getAlbums() -> [Album] {
        return mockAlbums
    }
    
    func getArtists() -> [Artist] {
        var artists = mockArtists
        
        for i in 0..<artists.count {
            let artistAlbums = mockAlbums.filter { $0.artist == artists[i].name }
            artists[i] = Artist(id: artists[i].id, position: artists[i].position, name: artists[i].name, albums: artistAlbums)
        }
        
        return artists
    }
    
    func getSongs() -> [Song] {
        return mockSongs
    }
    
    func getSongs(for artist: Artist) -> [Song] {
        return mockSongs.filter { $0.artist == artist.name }
    }
    
    func getSongs(for album: Album) -> [Song] {
        return mockSongs.filter {
            $0.url.absoluteString.contains(album.url.absoluteString) 
        }
    }
    
    func getSongs(for playlist: Playlist) -> [Song] {
        if playlist.name == "Favorites" {
            return mockFavorites
        } else if playlist.name == "Rock Classics" {
            return [mockSongs[7], mockSongs[9]]
        } else if playlist.name == "60s and 70s" {
            return [mockSongs[0], mockSongs[4], mockSongs[10]]
        }
        
        return []
    }
    
    func getPlaylists() -> [Playlist] {
        return mockPlaylists
    }
    
    func getStatusData() -> (state: PlayerState?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?, playlist: Playlist?, song: Song?) {
        return mockStatus
    }
    
    func play(_ media: any Playable)  {
        if let song = media as? Song {
            mockStatus.song = song
            mockStatus.state = .play
            mockStatus.elapsed = 0.0
        } else if let album = media as? Album {
            let albumSongs = mockSongs.filter {
                $0.url.absoluteString.contains(album.url.absoluteString)
            }
            
            if let firstSong = albumSongs.first {
                mockStatus.song = firstSong
                mockStatus.state = .play
                mockStatus.elapsed = 0.0
            }
        }
    }
    
    func pause(_ value: Bool) {
        mockStatus.state = value ? .pause : .play
    }
    
    func previous() {
        if let currentSong = mockStatus.song, let index = mockSongs.firstIndex(where: { $0.id == currentSong.id }) {
            let newIndex = (index - 1 + mockSongs.count) % mockSongs.count
            mockStatus.song = mockSongs[newIndex]
            mockStatus.state = .play
            mockStatus.elapsed = 0.0
        }
    }
    
    func next() {
        if let currentSong = mockStatus.song, let index = mockSongs.firstIndex(where: { $0.id == currentSong.id }) {
            let newIndex = (index + 1) % mockSongs.count
            mockStatus.song = mockSongs[newIndex]
            mockStatus.state = .play
            mockStatus.elapsed = 0.0
        }
    }
    
    func `repeat`(_ value: Bool) {
        mockStatus.isRepeat = value
    }
    
    func random(_ value: Bool) {
        mockStatus.isRandom = value
    }
    
    func seek(_ value: Double) {
        if let song = mockStatus.song {
            mockStatus.elapsed = min(value, song.duration)
        }
    }
    
    func loadPlaylist(_ playlist: Playlist? = nil) {
        mockStatus.playlist = playlist
        
        if let playlist = playlist {
            let songs = getSongs(for: playlist)
            if let firstSong = songs.first {
                mockStatus.song = firstSong
                mockStatus.elapsed = 0.0
                mockStatus.state = .stop
            }
        } else {
            mockStatus.song = mockSongs.first
            mockStatus.elapsed = 0.0
            mockStatus.state = .stop
        }
    }
}
