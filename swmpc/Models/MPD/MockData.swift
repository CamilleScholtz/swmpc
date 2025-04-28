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

    private var currentPlaylist: Playlist?
    private var currentSong: Song? = Song(id: 1, position: 1, url: URL(string: "file:///music/Quantum%20Dragons/Nebula%20Dreams/01%20Starlight%20Symphony.mp3")!, artist: "Quantum Dragons", title: "Starlight Symphony", duration: 289.0, disc: 1, track: 1)

    // MARK: - Mock Data Generation

    private let mockArtists: [String] = [
        "Quantum Dragons", "Lunar Wolves", "Photon Symphony", "Digital Nebula",
        "The Timewalkers", "Hologram Weekend", "Crystal Vortex", "Solar Wind",
        "Prism + The Echoes", "The Wormhole Travelers", "Astral House", "Dimensional Portals",
        "Gravity Bears", "Cosmic Foxes", "Stellar Rós", "Hyperspace Stevens",
        "Quantum Mouse", "Parallel Universe", "The Bots", "Light Speed Taxi",
        "The Multiverse", "Waveform", "Neon Spoon", "Void Explorers", "Binary Broadcast",
        "Virtual Father", "Synthia", "Cybernetic Breakfast", "Mech Seat Headrest",
        "Alien Lizard Wizards", "Robot Bridgers", "Mega Thief",
        "Neural Milk Hotel", "Morning Starship", "The Meteors", "Anomaly Collective",
        "The Plasma Lips", "Starcluster M83", "Martian Generation", "Eclipse", "Quantum-J", "Data Stream",
        "Binary Social Scene", "Hologram Records", "Wolf Station", "Future Planets",
        "Virtual Estate", "The Astronomers", "Lunar Hunter", "Band of Nebulae",
    ]

    private let albumTitles: [String] = [
        "Singularity", "Quantum Mind", "In Starlight", "Sound of Antimatter", "Black Hole",
        "Modern Space Vampires", "Gravity Ripples", "For Stella, Forever Ago",
        "Interstellar Rituals", "Lost in the Void", "Lunar Cherry", "Turn On the Plasma Lights",
        "Nebula House", "Starship Blues", "Quasars...", "Martian Landscape",
        "Good News for People Who Love Space Travel", "Alpha Centauri Hotel", "Is This Reality", "Interdimensional",
        "Binary", "The Hologram", "Ga Ga Ga Ga Galaxy", "I Can Hear the Stars Singing", "Return to Alien Mountain",
        "I Love You, Cyberspace", "Be the Astronaut", "Solar System", "Teens of Another Dimension",
        "Infinity Loop", "Time Traveler", "Dragon New Warm Planet I Believe in You",
        "In the Spaceship Over the Void", "Zero Gravity", "Oh, Inverted Dimension", "Dark Matter Pavilion",
        "The Soft Supernova", "Hurry Up, We're Dreaming of Mars", "Interstellar Spectacular", "Virtual Worlds", "A Quantum Wave", "What Universe",
        "You Forgot It in Hyperspace", "Let's Get Out of This Galaxy", "Apologies to the Space Queen", "Binary Singles",
        "Light Years", "The Void King Is Dead", "Macrocosmos", "Everything All the Universe",
    ]

    private let songTitles: [String] = [
        "Starlight Symphony", "Do I Wanna Float?", "Lightspeed Step", "Martian Scum", "Quantum Empire",
        "Hyper-Jump", "Let It Implode", "Cosmic Love", "Shake The Universe", "Nebula Eyes", "Star Song", "Galaxy Obstacle",
        "Two Wormholes", "Alpha Centauri", "Pulsar", "Earthship", "Float Through Space", "I Am Trying to Break the Space-Time Continuum", "Last Light", "Quantum Registration",
        "Event Horizon", "Binary Code", "The Star Wanderer", "Cosmic Winter", "Wolf-Like Alien",
        "Space Station #4", "Android", "Stardust", "Fill in the Dark Matter",
        "Gamma Ray Knife", "Mars Base", "Reality Swarm",
        "King of Quantum Particles", "Wordless Cosmos", "New Dimension", "My Stars",
        "Race for the Planets", "Midnight Galaxy", "Time to Transcend", "Space Genesis", "Gravitational Waves", "Die Star",
        "Anthems for a Light Year Child", "Lloyd, I'm Ready to Be Teleported", "I'll Believe in Aliens", "Seasons (Waiting on Starlight)",
        "It's Virtual", "Down by the Black Hole", "Nothing Ever Decayed", "The Supernova",
        "Life on Jupiter?", "Space Heroes", "Under Zero Gravity", "Space Oddities",
        "Quantum Leap", "Paranoid Android 2.0", "Cosmic Police", "Fake Holographic Trees",
        "Sounds Like Space Wind", "Come As You Are Projected", "In Bloom on Mars", "Wormhole-Shaped Box",
        "Sweet Child Of Mine Galaxy", "Welcome to the Dark Matter", "Paradise Planet", "November Meteor Shower",
        "Space Walker", "Binary Jean", "Beat The Alien", "Smooth Space Criminal",
        "Quantum Rhapsody", "We Will Rock The Planets", "Another One Enters The Void", "Don't Stop Me Now I'm In Orbit",
        "Hey Alien", "Let It Be In Space", "Come Together Under The Stars", "Here Comes the Binary Sun",
    ]

    private let yearRange = 1990 ... 2055

    private lazy var mockAlbums: [Album] = generateMockAlbums()
    private lazy var mockSongs: [Song] = generateMockSongs()
    private lazy var mockPlaylists: [Playlist] = generateMockPlaylists()

    private func generateMockAlbums() -> [Album] {
        var albums: [Album] = []

        for (index, artist) in mockArtists.enumerated() {
            let numAlbums = (index % 3) + 1

            for albumIndex in 0 ..< numAlbums {
                let id = UInt32(albums.count + 1)
                let position = id

                let albumTitle = albumTitles[(index + albumIndex) % albumTitles.count]

                let releaseYear = String(Int.random(in: yearRange))

                let escapedArtist = artist.replacingOccurrences(of: " ", with: "%20")
                let escapedAlbum = albumTitle.replacingOccurrences(of: " ", with: "%20")
                let url = URL(string: "file:///music/\(escapedArtist)/\(escapedAlbum)")!

                let album = Album(
                    id: id,
                    position: position,
                    url: url,
                    artist: artist,
                    title: albumTitle,
                    date: releaseYear
                )

                albums.append(album)
            }
        }

        return albums
    }

    private func generateMockSongs() -> [Song] {
        var songs: [Song] = []

        for (index, album) in mockAlbums.enumerated() {
            let numSongs = Int.random(in: 5 ... 12)

            for songIndex in 0 ..< numSongs {
                let id = UInt32(songs.count + 1)
                let position = id

                let songTitle = songTitles[(index + songIndex) % songTitles.count]

                let duration = Double.random(in: 120 ... 480)

                let trackNum = String(format: "%02d", songIndex + 1)
                let escapedSong = songTitle.replacingOccurrences(of: " ", with: "%20")
                let songUrl = URL(string: "\(album.url.absoluteString)/\(trackNum)%20\(escapedSong).mp3")!

                let song = Song(
                    id: id,
                    position: position,
                    url: songUrl,
                    artist: album.artist,
                    title: songTitle,
                    duration: duration,
                    disc: 1,
                    track: songIndex + 1
                )

                songs.append(song)
            }
        }

        return songs
    }

    private func generateMockPlaylists() -> [Playlist] {
        [
            Playlist(name: "Favorites"),
            Playlist(name: "Nebula Vibes"),
            Playlist(name: "Morning Space Walk"),
            Playlist(name: "Zero-G Workout"),
            Playlist(name: "Starship Trip"),
        ]
    }

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
        switch playlist.name {
        case "Favorites":
            return Array(mockSongs.shuffled().prefix(15))
        case "Nebula Vibes":
            let nebulaArtists = ["Astral House", "Solar Wind", "Stellar Rós", "Cosmic Foxes"]
            let nebulaSongs = mockSongs.filter { nebulaArtists.contains($0.artist) }.shuffled()
            return Array(nebulaSongs.prefix(12))
        case "Morning Space Walk":
            return Array(mockSongs.shuffled().prefix(20))
        case "Zero-G Workout":
            let workoutArtists = ["Digital Nebula", "Lunar Wolves", "The Bots"]
            let workoutSongs = mockSongs.filter { workoutArtists.contains($0.artist) }.shuffled()
            return Array(workoutSongs.prefix(15))
        case "Starship Trip":
            return Array(mockSongs.shuffled().prefix(25))
        default:
            return []
        }
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
