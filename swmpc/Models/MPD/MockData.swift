//
//  MockData.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/04/2025.
//

import SwiftUI

actor MockData {
    static let shared = MockData()

    private init() {}

    // MARK: - Internal State

    private var state: PlayerState = .stop
    private var isRandom = false
    private var isRepeat = false
    private var elapsed: Double = 0.0

    private var currentPlaylist: Playlist? = Playlist(name: "Rock Classics")
    private var currentSong: Song? = Song(id: 1, position: 1, url: URL(string: "file:///music/The%20Beatles/Abbey%20Road/01%20Come%20Together.mp3")!, artist: "The Beatles", title: "Come Together", duration: 259.0, disc: 1, track: 1)

    private let mockAlbums: [Album] = [
        Album(id: 1, position: 1, url: URL(string: "file:///music/The%20Beatles/Abbey%20Road")!, artist: "The Beatles", title: "Abbey Road", date: "1969"),
        Album(id: 2, position: 2, url: URL(string: "file:///music/Pink%20Floyd/Dark%20Side%20of%20the%20Moon")!, artist: "Pink Floyd", title: "The Dark Side of the Moon", date: "1973"),
        Album(id: 3, position: 3, url: URL(string: "file:///music/Queen/A%20Night%20at%20the%20Opera")!, artist: "Queen", title: "A Night at the Opera", date: "1975"),
    ]

    private let mockSongs: [Song] = [
        Song(id: 1, position: 1, url: URL(string: "file:///music/The%20Beatles/Abbey%20Road/01%20Come%20Together.mp3")!, artist: "The Beatles", title: "Come Together", duration: 259.0, disc: 1, track: 1),
        Song(id: 2, position: 2, url: URL(string: "file:///music/The%20Beatles/Abbey%20Road/02%20Something.mp3")!, artist: "The Beatles", title: "Something", duration: 183.0, disc: 1, track: 2),
        Song(id: 3, position: 3, url: URL(string: "file:///music/Pink%20Floyd/Dark%20Side%20of%20the%20Moon/01%20Time.mp3")!, artist: "Pink Floyd", title: "Time", duration: 421.0, disc: 1, track: 1),
        Song(id: 4, position: 4, url: URL(string: "file:///music/Queen/A%20Night%20at%20the%20Opera/09%20Bohemian%20Rhapsody.mp3")!, artist: "Queen", title: "Bohemian Rhapsody", duration: 354.0, disc: 1, track: 9),
    ]

    private let mockPlaylists: [Playlist] = [
        Playlist(name: "Favorites"),
        Playlist(name: "Rock Classics"),
    ]

    // MARK: - Mock Command Functions

    func getStatusData() -> (state: PlayerState?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?, playlist: Playlist?, song: Song?) {
        (state, isRandom, isRepeat, elapsed, currentPlaylist, currentSong)
    }

    func getAlbums() -> [Album] {
        mockAlbums
    }

    func getArtists() -> [Artist] {
        Dictionary(grouping: mockAlbums, by: { $0.artist })
            .map { artist, albums in
                Artist(id: albums.first!.id, position: albums.first!.position, name: artist, albums: albums)
            }
            .sorted { $0.position < $1.position }
    }

    func getSongs() -> [Song] {
        mockSongs
    }

    func getSongs(for artist: Artist) -> [Song] {
        mockSongs.filter { $0.artist == artist.name }
    }

    func getSongs(for album: Album) -> [Song] {
        mockSongs.filter { $0.url.absoluteString.contains(album.url.absoluteString) }
    }

    func getSongs(for playlist: Playlist) -> [Song] {
        if playlist.name == "Favorites" {
            return [mockSongs[0], mockSongs[3]]
        } else if playlist.name == "Rock Classics" {
            return [mockSongs[2], mockSongs[3]]
        }

        return []
    }

    func getPlaylists() -> [Playlist] {
        mockPlaylists
    }

    func generateMockArtwork(for url: URL) -> Data {
        let hash = abs(url.absoluteString.hashValue)

        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash >> 16) % 360) / 360.0

        let size = CGSize(width: 300, height: 300)

        #if os(iOS)
            UIGraphicsBeginImageContextWithOptions(size, true, 0)
            guard let context = UIGraphicsGetCurrentContext() else { return Data() }

            let startColor = UIColor(hue: CGFloat(hue1), saturation: 0.4, brightness: 0.9, alpha: 1.0)
            let endColor = UIColor(hue: CGFloat(hue2), saturation: 0.4, brightness: 0.9, alpha: 1.0)
            let colors = [startColor.cgColor, endColor.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let locations: [CGFloat] = [0.0, 1.0]

            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
                UIGraphicsEndImageContext()
                return Data()
            }

            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: size.width, y: size.height),
                                       options: [])

            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return image?.pngData() ?? Data()

        #elseif os(macOS)
            let image = NSImage(size: size)
            image.lockFocus()
            guard let context = NSGraphicsContext.current?.cgContext else {
                image.unlockFocus()
                return Data()
            }

            let startColor = NSColor(calibratedHue: CGFloat(hue1), saturation: 0.4, brightness: 0.9, alpha: 1.0)
            let endColor = NSColor(calibratedHue: CGFloat(hue2), saturation: 0.4, brightness: 0.9, alpha: 1.0)
            let colors = [startColor.cgColor, endColor.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let locations: [CGFloat] = [0.0, 1.0]

            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
                image.unlockFocus()
                return Data()
            }

            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: size.width, y: size.height),
                                       options: [])

            image.unlockFocus()

            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:])
            else {
                return Data()
            }

            return pngData
        #endif
    }
}
