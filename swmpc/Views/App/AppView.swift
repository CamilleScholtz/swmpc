//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct AppView: View {
    @Environment(MPD.self) private var mpd

    @State private var selected = MediaType.album
    @State private var playlist: Playlist?
    @State private var path = NavigationPath()

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

                ForEach(mpd.categories.filter(\.list)) { category in
                    NavigationLink {
                        
                    } label: {
                        Label(category.label, systemImage: category.image)
                    }
                }

                Section("Playlists") {
                    Label("Favorites", systemImage: "heart")
                        .tag(MediaType.playlist)
                        .onTapGesture {
                            //playlist = "Favorites"
                            selected = .playlist
                        }

                    ForEach(mpd.queue.playlists ?? []) { playlist in
                        Label(playlist.name, systemImage: "music.note.list")
                            .tag(playlist.id)
                            .onTapGesture {
                                self.playlist = playlist
                                selected = .playlist
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
                if selected != .playlist {
                    playlist = nil
                }
                
                try? await mpd.queue.set(for: selected, using: playlist)

                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.queue.get(for: selected, using: song)
            }
            .task(id: mpd.status.song) {
                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.queue.get(for: selected, using: song)
            }
        } content: {
            ContentView(path: $path)
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
