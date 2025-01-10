//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

let categories: [Category] = [
    .init(type: MediaType.album, playlist: nil, label: "Albums", image: "square.stack"),
    .init(type: MediaType.artist, playlist: nil, label: "Artists", image: "music.microphone"),
    .init(type: MediaType.song, playlist: nil, label: "Songs", image: "music.note"),
]

struct AppView: View {
    @Environment(MPD.self) private var mpd

    @State private var selected = categories.first!
    @State private var path = NavigationPath()
    @State private var media: [any Mediable]?

    @State private var editingPlaylist = false
    @State private var playlistName = ""

    @FocusState private var playlistFocus: Bool

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                Text("swmpc")
                    .font(.system(size: 18))
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .padding(.bottom, 15)

                ForEach(categories) { category in
                    NavigationLink(value: category) {
                        Label(category.label, systemImage: category.image)
                    }
                }

                Section("Playlists") {
//                    NavigationLink(value: MediaType.playlist) {
//                        Label("Favorites", systemImage: "heart")
//                    }

                    ForEach(mpd.queue.playlists ?? []) { playlist in
                        let category = Category(type: .playlist, playlist: playlist, label: playlist.name, image: "music.note.list")

                        NavigationLink(value: category) {
                            Label(category.label, systemImage: category.image)
                        }
                    }

                    if editingPlaylist {
                        TextField("Untitled Playlist", text: $playlistName)
                            .focused($playlistFocus)
                            .onSubmit {
                                Task {
                                    try? await ConnectionManager().createPlaylist(named: playlistName)

                                    editingPlaylist = false
                                    playlistName = ""
                                    playlistFocus = false
                                }
                            }
                    }

                    Label("New Playlist", systemImage: "plus")
                        .onTapGesture(perform: {
                            editingPlaylist = true
                            playlistFocus = true
                        })
                }
            }
            .navigationSplitViewColumnWidth(180)
            .toolbar(removing: .sidebarToggle)
            .task(id: selected) {
                try? await mpd.queue.set(for: selected.type)

                if selected.type == .playlist {
                    guard let playlist = selected.playlist else {
                        return
                    }

                    media = try? await ConnectionManager().getPlaylist(playlist)
                } else {
                    media = mpd.queue.media
                }

                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.queue.get(for: selected.type, using: song)
            }
            .task(id: mpd.status.song) {
                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.queue.get(for: selected.type, using: song)
            }
        } content: {
            ContentView(media: $media, path: $path)
                .navigationBarBackButtonHidden()
                .navigationSplitViewColumnWidth(310)
        } detail: {
            ViewThatFits {
                DetailView(path: $path)
            }
            .padding(60)
        }
        .background(.background)
        .toolbar {
            Color.clear
        }
    }
}
