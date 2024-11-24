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
    case idleStateError
}

actor ConnectionManager {
    @AppStorage(Setting.host) var host = "localhost"
    @AppStorage(Setting.port) var port = 6600

    private var connection: OpaquePointer?
    private(set) var isConnected = false

    private var idle: Bool

    init(idle: Bool = false) {
        self.idle = idle
    }

    private func run(_ action: (OpaquePointer) -> Void) throws {
        try? connect()
        defer { disconnect() }

        guard let connection else {
            throw ConnectionManagerError.connectionError
        }

        action(connection)
    }

    func connect() throws {
        disconnect()

        connection = mpd_connection_new(host, UInt32(port), 0)
        guard mpd_connection_get_error(connection) == MPD_ERROR_SUCCESS else {
            throw ConnectionManagerError.connectionError
        }

        isConnected = true

        if idle {
            mpd_connection_set_keepalive(connection, true)
        }
    }

    func disconnect() {
        guard let connection else {
            return
        }

        mpd_connection_free(connection)
        self.connection = nil

        isConnected = false
    }

    func runPlay(_ id: UInt32) {
        try! run { _ in
            mpd_run_play_id(connection, id)
        }
    }

    func runPause(_ value: Bool) {
        try! run { connection in
            mpd_run_pause(connection, value)
        }
    }

    func runPrevious() {
        try! run { connection in
            mpd_run_previous(connection)
        }
    }

    func runNext() {
        try! run { connection in
            mpd_run_next(connection)
        }
    }

    func runSeekCurrent(_ value: Double) {
        try! run { connection in
            mpd_run_seek_current(connection, Float(value), false)
        }
    }

    func runRandom(_ value: Bool) {
        try! run { connection in
            mpd_run_random(connection, value)
        }
    }

    func runRepeat(_ value: Bool) {
        try! run { connection in
            mpd_run_repeat(connection, value)
        }
    }

    func runIdleMask(mask: mpd_idle) -> mpd_idle {
        guard let connection else {
            return mpd_idle(0)
        }
        return mpd_run_idle_mask(connection, mask)
    }

    func getStatusData() throws -> (isPlaying: Bool?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?) {
        guard idle else {
            throw ConnectionManagerError.idleStateError
        }

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

    func getAlbums() throws -> [Album] {
        guard !idle else {
            throw ConnectionManagerError.idleStateError
        }

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
            let song = getSong(recv: recv)
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

    func getSong(recv: OpaquePointer?) -> Song? {
        guard recv != nil else {
            return nil
        }

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
        let id = mpd_song_get_id(recv)
        let uri = String(cString: mpd_song_get_uri(recv))

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

    func getCurrentSong() throws -> Song? {
        guard idle else {
            throw ConnectionManagerError.idleStateError
        }

        guard let connection, let recv = mpd_run_current_song(connection) else {
            return nil
        }
        defer { mpd_song_free(recv) }

        let song = getSong(recv: recv)

        return song
    }

    func getSongs(for album: Album? = nil) throws -> [Song] {
        guard !idle else {
            throw ConnectionManagerError.idleStateError
        }

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
            let song = getSong(recv: recv)
            guard let song else {
                continue
            }

            songs.append(song)
        }

        return songs
    }

    func getElapsedData() throws -> Double? {
        guard !idle else {
            throw ConnectionManagerError.idleStateError
        }

        try connect()
        defer { disconnect() }

        guard let connection, let recv = mpd_run_status(connection) else {
            return nil
        }
        defer { mpd_status_free(recv) }

        return Double(mpd_status_get_elapsed_time(recv))
    }

    func getArtwork(for uri: URL, embedded: Bool = true) throws -> NSImage? {
        guard !idle else {
            throw ConnectionManagerError.idleStateError
        }

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
}
