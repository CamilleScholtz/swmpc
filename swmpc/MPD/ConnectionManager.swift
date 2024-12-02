//
//  ConnectionManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import libmpdclient
import SwiftUI

enum ConnectionManagerError: Error {
    case connectionError
}

protocol ConnectionManager: Actor {
    var host: String { get }
    var port: Int { get }

    var connection: OpaquePointer? { get set }
    var isConnected: Bool { get set }
}

extension ConnectionManager {
    func connect(isolation: isolated ConnectionManager = #isolation, idle: Bool = false) throws {
        disconnect()

        isolation.connection = mpd_connection_new(isolation.host, UInt32(isolation.port), 0)
        guard mpd_connection_get_error(isolation.connection) == MPD_ERROR_SUCCESS else {
            throw ConnectionManagerError.connectionError
        }

        if idle {
            mpd_connection_set_keepalive(isolation.connection, true)
        }

        isolation.isConnected = true
    }

    func disconnect(isolation: isolated ConnectionManager = #isolation) {
        guard isolation.connection != nil else {
            return
        }

        mpd_connection_free(isolation.connection)
        isolation.connection = nil

        isolation.isConnected = false
    }

    func getSong(isolation _: isolated ConnectionManager = #isolation, recv: OpaquePointer?) async -> Song? {
        guard recv != nil else {
            return nil
        }

        let id = mpd_song_get_id(recv)
        let uri = String(cString: mpd_song_get_uri(recv))

        var artist: String?
        if let tag = mpd_song_get_tag(recv, MPD_TAG_ARTIST, 0) {
            artist = String(cString: tag)
        }

        var title: String?
        if let tag = mpd_song_get_tag(recv, MPD_TAG_TITLE, 0) {
            title = String(cString: tag)
        }

        var track: Int?
        if let tag = mpd_song_get_tag(recv, MPD_TAG_TRACK, 0) {
            track = Int(String(cString: tag))
        }

        var disc: Int?
        if let tag = mpd_song_get_tag(recv, MPD_TAG_DISC, 0) {
            disc = Int(String(cString: tag))
        }

        let duration = Double(mpd_song_get_duration(recv))

        return Song(
            id: id,
            uri: URL(string: uri)!,
            artist: artist ?? "Unknown Artist",
            title: title ?? "Unknown Title",
            duration: duration,
            disc: disc ?? 1,
            track: track ?? 1
        )
    }
}

actor IdleManager: ConnectionManager {
    static let shared = IdleManager()

    @AppStorage(Setting.host) var host = "localhost"
    @AppStorage(Setting.port) var port = 6600

    var connection: OpaquePointer?
    var isConnected = false

    private init() {}

    func runIdleMask(mask: mpd_idle) -> mpd_idle {
        guard let connection else {
            return mpd_idle(0)
        }

        return mpd_run_idle_mask(connection, mask)
    }

    func getStatusData() async throws -> (isPlaying: Bool?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?) {
        guard let connection, let recv = mpd_run_status(connection) else {
            return (nil, nil, nil, nil)
        }
        defer { mpd_status_free(recv) }

        let isPlaying = mpd_status_get_state(recv) == MPD_STATE_PLAY
        let isRandom = mpd_status_get_random(recv)
        let isRepeat = mpd_status_get_repeat(recv)
        let elapsed = Double(mpd_status_get_elapsed_time(recv))

        return (isPlaying, isRandom, isRepeat, elapsed)
    }

    func getCurrentSong() async throws -> Song? {
        guard let connection, let recv = mpd_run_current_song(connection) else {
            return nil
        }
        defer { mpd_song_free(recv) }

        let song = await getSong(recv: recv)

        return song
    }

    func getPlaylists() async throws -> [Playlist] {
        guard let connection, mpd_send_list_playlists(connection) else {
            return []
        }

        var playlists = [Playlist]()
        var index = UInt32(0)
        while let recv = mpd_recv_playlist(connection) {
            defer { mpd_playlist_free(recv) }

            index += 1

            playlists.append(Playlist(
                id: index,
                name: String(cString: mpd_playlist_get_path(recv))
            ))
        }

        return playlists
    }
}

actor CommandManager: ConnectionManager {
    static let shared = CommandManager()

    @AppStorage(Setting.host) var host = "localhost"
    @AppStorage(Setting.port) var port = 6600

    var connection: OpaquePointer?
    var isConnected = false

    private init() {}

    private func run(_ action: (OpaquePointer) -> Void) async throws {
        try connect()
        defer { disconnect() }

        guard let connection else {
            throw ConnectionManagerError.connectionError
        }

        action(connection)
    }

    func play(_ media: any Mediable) async {
        try? await run { _ in
            mpd_run_play_id(connection, media.id)
        }
    }

    func pause(_ value: Bool) async {
        try? await run { connection in
            mpd_run_pause(connection, value)
        }
    }

    func previous() async {
        try? await run { connection in
            mpd_run_previous(connection)
        }
    }

    func next() async {
        try? await run { connection in
            mpd_run_next(connection)
        }
    }

    func seek(_ value: Double) async {
        try? await run { connection in
            mpd_run_seek_current(connection, Float(value), false)
        }
    }

    func random(_ value: Bool) async {
        try? await run { connection in
            mpd_run_random(connection, value)
        }
    }

    func `repeat`(_ value: Bool) async {
        try? await run { connection in
            mpd_run_repeat(connection, value)
        }
    }

    func getAlbums() async throws -> [Album] {
        try connect()
        defer { disconnect() }

        var albums = [Album]()

        guard mpd_search_queue_songs(connection, true),
              mpd_search_add_tag_constraint(connection, MPD_OPERATOR_DEFAULT, MPD_TAG_TRACK, "1"),
              mpd_search_add_tag_constraint(connection, MPD_OPERATOR_DEFAULT, MPD_TAG_DISC, "1"),
              mpd_search_commit(connection)
        else {
            return []
        }

        while let recv = mpd_recv_song(connection) {
            let song = await getSong(recv: recv)
            guard let song else {
                continue
            }

            var artist: String?
            if let tag = mpd_song_get_tag(recv, MPD_TAG_ALBUM_ARTIST, 0) {
                artist = String(cString: tag)
            }

            var title: String?
            if let tag = mpd_song_get_tag(recv, MPD_TAG_ALBUM, 0) {
                title = String(cString: tag)
            }

            var date: String?
            if let tag = mpd_song_get_tag(recv, MPD_TAG_DATE, 0) {
                date = String(cString: tag)
            }

            albums.append(Album(
                id: song.id,
                uri: song.uri,
                artist: artist ?? "Unknown Artist",
                title: title ?? "Unknown Title",
                date: date ?? "1970"
            ))
        }

        return albums
    }

    func getSongs(for album: Album? = nil) async throws -> [Song] {
        try connect()
        defer { disconnect() }

        if let album {
            guard mpd_search_queue_songs(connection, true),
                  mpd_search_add_tag_constraint(connection, MPD_OPERATOR_DEFAULT, MPD_TAG_ALBUM, album.title),
                  mpd_search_commit(connection)
            else {
                return []
            }
        } else {
            mpd_send_list_queue_meta(connection)
        }

        var songs = [Song]()
        while let recv = mpd_recv_song(connection) {
            let song = await getSong(recv: recv)
            guard let song else {
                continue
            }

            songs.append(song)
        }

        return songs
    }

    func getElapsedData() async throws -> Double? {
        try connect()
        defer { disconnect() }

        guard let connection, let recv = mpd_run_status(connection) else {
            return nil
        }
        defer { mpd_status_free(recv) }

        return Double(mpd_status_get_elapsed_time(recv))
    }

    func getArtwork(for uri: URL, embedded: Bool = true) async throws -> NSImage? {
        var data = Data()
        var offset: UInt32 = 0
        let bufferSize = 512 * 512
        var buffer = Data(count: bufferSize)

        try connect()
        defer { disconnect() }

        while true {
            let recv = buffer.withUnsafeMutableBytes { bufferPtr in
                if embedded {
                    mpd_run_readpicture(connection, uri.path, offset, bufferPtr.baseAddress, bufferSize)
                } else {
                    mpd_run_albumart(connection, uri.path, offset, bufferPtr.baseAddress, bufferSize)
                }
            }
            guard recv > 0 else {
                break
            }

            data.append(buffer.prefix(Int(recv)))
            offset += UInt32(recv)
        }

        return NSImage(data: data)
    }

    func createPlaylist(named name: String) async throws {
        try connect()
        defer { disconnect() }

        mpd_run_save(connection, name)
    }

    func addToPlaylist(_ songs: [Song], playlist: Playlist) async throws {
        try connect()
        defer { disconnect() }

        for song in songs {
            mpd_run_playlist_add(connection, playlist.name, song.uri.path)
        }
    }
}
