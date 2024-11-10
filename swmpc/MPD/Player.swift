//
//  Player.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import libmpdclient
import SwiftUI

@Observable final class Player {
    let status: Status
    let queue: Queue

    var current: Song?

    private(set) var artworkCache: [String: Artwork] = [:]

    @ObservationIgnored let idleManager = ConnectionManager(idle: true)
    @ObservationIgnored let commandManager = ConnectionManager()

    private var updateLoopTask: Task<Void, Never>?

    @MainActor
    init() {
        status = Status(idleManager: idleManager, commandManager: commandManager)
        queue = Queue(idleManager: idleManager, commandManager: commandManager)

        updateLoopTask = Task { [weak self] in
            await self?.updateLoop()
        }
    }

    deinit {
        updateLoopTask?.cancel()
    }

    @MainActor
    private func updateLoop() async {
        while !Task.isCancelled {
            if await (!idleManager.isConnected) {
                await idleManager.connect()
                if await (!idleManager.isConnected) {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    continue
                }
            }

            await status.set()
            if await current.update(to: idleManager.getSong()) {
                AppDelegate.shared.setStatusItemTitle()
            }

            let idleResult = await idleManager.runIdleMask(
                mask: mpd_idle(MPD_IDLE_PLAYER.rawValue | MPD_IDLE_OPTIONS.rawValue)
            )

            if idleResult == mpd_idle(0) {
                await idleManager.disconnect()
            }
        }
    }

    @MainActor
    func setArtwork(for uri: String) async {
        // TODO: Is there a smarter way of doing this? Is it even needed?
        if artworkCache.count > 64 {
            let oldest = artworkCache.min {
                guard $0.value.timestamp != nil, $1.value.timestamp != nil else {
                    return false
                }

                return $0.value.timestamp! < $1.value.timestamp!
            }

            oldest!.value.image = nil
            artworkCache.removeValue(forKey: oldest!.key)
        }

        guard artworkCache[uri] == nil else {
            return
        }

        let artwork = Artwork(uri: uri)
        artworkCache[uri] = artwork

        await artwork.set(using: commandManager)
    }

    @MainActor
    func getArtwork(for uri: String?) -> Artwork? {
        guard let uri else {
            return nil
        }

        return artworkCache[uri]
    }

    @MainActor
    func pause(_ value: Bool) async {
        await commandManager.runPause(value)
    }

    @MainActor
    func previous() async {
        await commandManager.runPrevious()
    }

    @MainActor
    func next() async {
        await commandManager.runNext()
    }

    @MainActor
    func seek(_ value: Double) async {
        await commandManager.runSeekCurrent(value)
        status.elapsed = value
    }

    @MainActor
    func setRandom(_ value: Bool) async {
        await commandManager.runRandom(value)
    }

    @MainActor
    func setRepeat(_ value: Bool) async {
        await commandManager.runRepeat(value)
    }
}

actor ConnectionManager {
    @AppStorage(Setting.host) var host = "localhost"
    @AppStorage(Setting.port) var port = 6600

    private var connection: OpaquePointer?
    private(set) var isConnected: Bool = false

    private var idle: Bool

    init(idle: Bool = false) {
        self.idle = idle
    }

    private func run(_ action: (OpaquePointer) -> Void) {
        connect()
        defer { disconnect() }

        guard let connection else {
            return
        }

        action(connection)
    }

    func connect() {
        disconnect()

        connection = mpd_connection_new(host, UInt32(port), 0)
        guard mpd_connection_get_error(connection) == MPD_ERROR_SUCCESS else {
            return
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

    func runPause(_ value: Bool) {
        run { connection in
            mpd_run_pause(connection, value)
        }
    }

    func runPrevious() {
        run { connection in
            mpd_run_previous(connection)
        }
    }

    func runNext() {
        run { connection in
            mpd_run_next(connection)
        }
    }

    func runSeekCurrent(_ value: Double) {
        run { connection in
            mpd_run_seek_current(connection, Float(value), false)
        }
    }

    func runRandom(_ value: Bool) {
        run { connection in
            mpd_run_random(connection, value)
        }
    }

    func runRepeat(_ value: Bool) {
        run { connection in
            mpd_run_repeat(connection, value)
        }
    }

    func runIdleMask(mask: mpd_idle) -> mpd_idle {
        guard let connection else {
            return mpd_idle(0)
        }
        return mpd_run_idle_mask(connection, mask)
    }

    // TODO: Throw error if idle is false.
    func getStatusData() -> (isPlaying: Bool?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?) {
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

    // TODO: Throw error if idle is true.
    func getQueue(using type: MediaType) async -> [Mediable] {
        connect()
        defer { disconnect() }

        guard mpd_search_queue_songs(connection, true) else {
            return []
        }

        switch type {
        case .album:
            return getAlbums()
        case .artist:
            return getArtists()
        default:
            return getSongs()
        }
    }

    func getAlbums() -> [Album] {
        var albums = [Album]()

        guard mpd_search_add_tag_constraint(connection, MPD_OPERATOR_DEFAULT, MPD_TAG_TRACK, "1"),
              mpd_search_add_tag_constraint(connection, MPD_OPERATOR_DEFAULT, MPD_TAG_DISC, "1"),
              mpd_search_commit(connection)
        else {
            return []
        }

        while let recv = mpd_recv_song(connection) {
            let song = getSong(receive: recv)
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
                artist: artist,
                title: title,
                date: date,
                songs: [song]
            ))
        }

        return albums
    }

    func getArtists() -> [Artist] {
        var artists = [Artist]()

        for album in getAlbums() {
            guard let artist = album.artist else {
                continue
            }

            if let index = artists.firstIndex(where: { $0.name == artist }) {
                artists[index].albums.append(album)
            } else {
                artists.append(Artist(
                    id: album.id,
                    name: artist,
                    albums: [album]
                )
                )
            }
        }

        return artists
    }

    func getSongs() -> [Song] {
        var songs = [Song]()

        return songs
    }

    func getSong(receive: OpaquePointer? = nil) -> Song? {
        var recv = receive
        if receive == nil {
            guard let connection else {
                return nil
            }

            recv = mpd_run_current_song(connection)
        }

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

        let duration = Double(mpd_song_get_duration(recv))
        let uri = String(cString: mpd_song_get_uri(recv))

        if receive == nil {
            mpd_song_free(recv)
        }

        return Song(
            id: uri,
            artist: artist,
            title: title,
            duration: duration
        )
    }

    func getElapsedData() -> Double? {
        connect()
        defer { disconnect() }

        guard let connection, let recv = mpd_run_status(connection) else {
            return nil
        }

        return Double(mpd_status_get_elapsed_time(recv))
    }

    func getArtwork(for uri: String, embedded: Bool = false) -> NSImage? {
        var data = Data()
        var offset: UInt32 = 0
        let bufferSize = 1024 * 1024
        var buffer = Data(count: bufferSize)

        connect()
        defer { disconnect() }

        while true {
            let recv = buffer.withUnsafeMutableBytes { bufferPtr in
                if embedded {
                    mpd_run_albumart(connection, uri, offset, bufferPtr.baseAddress, bufferSize)
                } else {
                    mpd_run_readpicture(connection, uri, offset, bufferPtr.baseAddress, bufferSize)
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
