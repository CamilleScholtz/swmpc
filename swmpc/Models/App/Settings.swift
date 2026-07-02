//
//  Settings.swift
//  swmpc
//
//  Created by Camille Scholtz on 25/03/2025.
//

nonisolated enum Setting {
    static let servers = "servers"
    static let selectedServerID = "selected_server_id"

    #if os(macOS)
        static let showStatusBar = "show_status_bar"
        static let showStatusbarSong = "show_statusbar_song"
    #endif

    static let intelligenceModel = "intelligence_model"
    static let customHost = "custom_host"

    static let albumSearchFields = "album_search_fields"
    static let artistSearchFields = "artist_search_fields"
    static let songSearchFields = "song_search_fields"

    static let albumSortOption = "album_sort_option"
    static let artistSortOption = "artist_sort_option"
    static let songSortOption = "song_sort_option"
}
