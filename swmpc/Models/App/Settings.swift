//
//  Settings.swift
//  swmpc
//
//  Created by Camille Scholtz on 25/03/2025.
//

nonisolated enum Setting {
    static let servers = "servers"
    static let selectedServerID = "selected_server_id"

    static let host = "host"
    static let port = "port"
    static let password = "password"
    static let artworkGetter = "artwork_getter"

    #if os(macOS)
        static let showStatusBar = "show_status_bar"
        static let showStatusbarSong = "show_statusbar_song"
    #endif

    static let isIntelligenceEnabled = "is_intelligence_enabled"
    static let intelligenceModel = "intelligence_model"

    static let openAIToken = "openai_token"
    static let deepSeekToken = "deepseek_token"
    static let geminiToken = "gemini_token"
    static let grokToken = "grok_token"
    static let claudeToken = "claude_token"

    static let albumSearchFields = "album_search_fields"
    static let artistSearchFields = "artist_search_fields"
    static let songSearchFields = "song_search_fields"

    static let albumSortOption = "album_sort_option"
    static let artistSortOption = "artist_sort_option"
    static let songSortOption = "song_sort_option"
}
