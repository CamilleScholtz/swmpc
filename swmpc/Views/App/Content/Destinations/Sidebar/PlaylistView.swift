//
//  PlaylistView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct PlaylistView: View {
    @Environment(MPD.self) private var mpd

    @AppStorage(Setting.scrollToCurrent) private var scrollToCurrent = false

    private let playlist: Playlist

    init(for playlist: Playlist) {
        self.playlist = playlist
    }

    var body: some View {
        SongsView()
    }
}
