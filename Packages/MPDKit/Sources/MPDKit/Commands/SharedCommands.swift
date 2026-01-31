//
//  SharedCommands.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import Foundation

/// Shared commands available to all connection modes.
public extension ConnectionManager {
    /// Retrieves the current status of the media player from the server.
    ///
    /// This asynchronous function sends a command list containing "status" and
    /// "currentsong" to the server. It parses the combined response to extract
    /// various status parameters and the full details of the currently playing
    /// song, avoiding the need for a second network call.
    ///
    /// - Returns: A tuple containing:
    ///   - `state`: The current player state (`play`, `pause`, or `stop`).
    ///   - `isConsume`: A Boolean indicating if consume playback is enabled.
    ///   - `isRandom`: A Boolean indicating if random playback is enabled.
    ///   - `isRepeat`: A Boolean indicating if repeat playback is enabled.
    ///   - `elapsed`: The elapsed playback time in seconds.
    ///   - `song`: The currently playing song, if any.
    ///   - `volume`: The current volume level (0-100).
    /// - Throws: An error if the response is malformed or if the underlying
    ///           command execution fails.
    func getStatusData() async throws -> (state: PlayerState?, isConsume: Bool?,
                                          isRandom: Bool?, isRepeat: Bool?,
                                          elapsed: Double?, song: Song?, volume:
                                          Int?)
    {
        let lines = try await run(["status", "currentsong"])

        var fields: [String: String] = [:]
        for line in lines where line != "OK" {
            let (key, value) = try parseLine(line)
            fields[key] = value
        }

        let state: PlayerState?
        if let stateValue = fields["state"] {
            switch stateValue {
            case "play": state = .play
            case "pause": state = .pause
            case "stop": state = .stop
            default:
                throw ConnectionManagerError.malformedResponse(
                    "Invalid player state: \(stateValue)")
            }
        } else {
            state = nil
        }

        let isConsume = fields["consume"].map { $0 == "1" }
        let isRandom = fields["random"].map { $0 == "1" }
        let isRepeat = fields["repeat"].map { $0 == "1" }
        let elapsed = fields["elapsed"].flatMap(Double.init)
        let volume = fields["volume"].flatMap(Int.init)

        let song: Song? = if fields["file"] != nil {
            try parseMediaResponse(fields.map {
                "\($0.key): \($0.value)"
            }, as: .song)
        } else {
            nil
        }

        return (state, isConsume, isRandom, isRepeat, elapsed, song, volume)
    }

    /// Retrieves statistics from the MPD server.
    ///
    /// This method fetches database and playback statistics from the MPD server,
    /// including counts of artists, albums, and songs, as well as uptime and
    /// playtime information.
    ///
    /// - Returns: A tuple containing:
    ///   - `artists`: The number of artists in the database.
    ///   - `albums`: The number of albums in the database.
    ///   - `songs`: The number of songs in the database.
    ///   - `uptime`: The daemon uptime in seconds.
    ///   - `playtime`: The sum of all song times in the database in seconds.
    ///   - `update`: The last database update in UNIX time.
    /// - Throws: An error if the response is malformed or if the underlying
    ///           command execution fails.
    func getStatsData() async throws -> (artists: Int?, albums: Int?,
                                         songs: Int?, uptime: Int?,
                                         playtime: Int?, update: Int?)
    {
        let lines = try await run(["stats"])

        var fields: [String: String] = [:]
        for line in lines where line != "OK" {
            let (key, value) = try parseLine(line)
            fields[key] = value
        }

        let artists = fields["artists"].flatMap(Int.init)
        let albums = fields["albums"].flatMap(Int.init)
        let songs = fields["songs"].flatMap(Int.init)
        let uptime = fields["uptime"].flatMap(Int.init)
        let playtime = fields["db_playtime"].flatMap(Int.init)
        let update = fields["db_update"].flatMap(Int.init)

        return (artists, albums, songs, uptime, playtime, update)
    }

    /// Retrieves all unique albums from the database, sorted as specified.
    ///
    /// This method fetches a list of songs (specifically, the first track of
    /// each album) and then extracts the unique albums from that list.
    ///
    /// - Note: We currently use the `find` command to retrieve albums. I'd
    ///         rather use `list`, but that has no sort option.
    ///
    /// - Parameter sort: The sorting descriptor containing the option and
    ///                   direction for sorting albums.
    /// - Returns: An array of unique `Album` objects.
    /// - Throws: An error if the command fails or the response is malformed.
    func getAlbums(sort: SortDescriptor = SortDescriptor.default) async throws
        -> [Album]
    {
        let lines = try await run(["find \(filter(key: "track", value: "1")) sort \(sort.direction.rawValue)\(sort.option.rawValue)"])

        let albums: [Album] = try parseMediaResponseArray(lines, as: .album)

        var seen: Set<String> = []
        var unique: [Album] = []

        for album in albums {
            if !seen.contains(album.id) {
                unique.append(album)
                seen.insert(album.id)
            }
        }

        return unique
    }

    /// Retrieves all albums by a specific artist from the given source.
    ///
    /// - Parameters:
    ///   - artist: The `Artist` to find albums for.
    ///   - source: The source to search within (either `.database` or
    ///             `.queue`).
    /// - Returns: An array of `Album` objects by the specified artist.
    /// - Throws: `ConnectionManagerError.unsupportedOperation` if the source is
    ///           not the database or queue.
    func getAlbums(by artist: Artist, from source: Source) async throws ->
        [Album]
    {
        let lines: [String]

        switch source {
        case .database:
            lines = try await run(["find \(filter(key: "albumartist", value: artist.name)) sort date"])
        case .queue:
            lines = try await run(["playlistfind \(filter(key: "albumartist", value: artist.name)) sort date"])
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only database and queue sources are supported for retrieving albums by artist")
        }

        let albums: [Album] = try parseMediaResponseArray(lines, as: .album)

        var seen: Set<String> = []
        var unique: [Album] = []

        for album in albums {
            if !seen.contains(album.id) {
                unique.append(album)
                seen.insert(album.id)
            }
        }

        return unique
    }

    /// Retrieves all unique artists from the database.
    ///
    /// This method first retrieves all unique albums and then extracts the
    /// unique artists from that list.
    ///
    /// - Parameter sort: The sorting descriptor used to retrieve albums, which
    ///                   indirectly affects the artist order.
    /// - Returns: An array of unique `Artist` objects.
    /// - Throws: An error if the underlying album lookup fails.
    func getArtists(sort: SortDescriptor = SortDescriptor.default) async throws
        -> [Artist]
    {
        let albums = try await getAlbums(sort: sort)

        var seen: Set<String> = []
        var unique: [Artist] = []

        for album in albums {
            let artist = album.artist

            if !seen.contains(artist.id) {
                unique.append(artist)
                seen.insert(artist.id)
            }
        }

        return unique
    }

    /// Retrieves all songs from a specified source.
    ///
    /// - Parameters:
    ///   - source: The source (`.database`, `.queue`, or a specific
    ///             `.playlist`) from which to retrieve the songs.
    ///   - sort: The sorting descriptor for database queries. Ignored for queue
    ///           and playlist sources.
    /// - Returns: An array of `Song` objects from the specified source.
    /// - Throws: An error if the command execution fails or if the response is
    ///           malformed.
    func getSongs(from source: Source, sort: SortDescriptor = SortDescriptor
        .default) async throws -> [Song]
    {
        let lines: [String]
        switch source {
        case .database:
            lines = try await run(["find \"(title != '')\" sort \(sort.direction.rawValue)\(sort.option.rawValue)"])
        case .queue:
            lines = try await run(["playlistinfo"])
        case .playlist, .favorites:
            guard let playlist = source.playlist else {
                throw ConnectionManagerError.unsupportedOperation(
                    "Playlist source has no associated playlist")
            }

            lines = try await run(["listplaylistinfo \(escape(playlist.name))"])
        }

        return try parseMediaResponseArray(lines, as: .song, index: true)
    }

    /// Retrieves songs from the database or queue that match a specific album.
    ///
    /// - Parameters:
    ///   - album: The `Album` object for which the songs should be retrieved.
    ///   - source: The source from which to retrieve the songs.
    /// - Returns: An array of `Song` objects corresponding to the specified
    ///            album.
    /// - Throws: An error if the command execution fails or if the response is
    ///           malformed.
    func getSongs(in album: Album, from source: Source) async throws -> [Song] {
        let filters = "\"(\(filter(key: "album", value: album.title, quote: false)) AND \(filter(key: "albumartist", value: album.artist.name, quote: false)))\""

        let lines = switch source {
        case .database:
            try await run(["find \(filters) sort track"])
        case .queue:
            try await run(["playlistfind \(filters)"])
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only database and queue sources are supported for retrieving songs in an album")
        }

        return try parseMediaResponseArray(lines, as: .song)
    }

    /// Retrieves all playlists.
    ///
    /// - Returns: An array of `Playlist` objects representing the available
    ///            playlists.
    /// - Throws: An error if the command execution fails or if the response is
    ///           malformed.
    func getPlaylists() async throws -> [Playlist] {
        let lines = try await run(["listplaylists"])
        var index: UInt32 = 0
        var playlists = [Playlist]()

        for line in lines {
            guard line != "OK" else {
                break
            }

            let (key, value) = try parseLine(line)

            if key == "playlist" {
                playlists.append(Playlist(name: value))

                index += 1
            }
        }

        return playlists
    }

    /// Gets the list of available audio outputs.
    ///
    /// - Returns: An array of `Output` objects representing available outputs.
    /// - Throws: An error if the underlying command execution fails.
    func getOutputs() async throws -> [Output] {
        let lines = try await run(["outputs"])
        let chunks = chunkLines(lines, startingWith: "outputid")

        return try chunks.compactMap { chunk in
            var fields: [String: String] = [:]
            for line in chunk where line != "OK" {
                let (key, value) = try parseLine(line)
                fields[key] = value
            }

            return Output(fields)
        }
    }
}
