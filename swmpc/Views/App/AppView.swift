//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct AppView: View {
    @Environment(Player.self) private var player

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

                ForEach(player.queue.categories.filter(\.list)) { category in
                    Label(category.label, systemImage: category.image)
                        .tag(category.id)
                }

                Section("Playlists") {
                    ForEach(player.playlists ?? []) { playlist in
                        Label(playlist.name, systemImage: "music.note.list")
                            .tag(MediaType.playlist)
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
                                    // TODOA
                                    // try? await CommandManager.shared.createPlaylist(named: playlistName)

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
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(180)
            .task(id: selected) {
                guard selected != .playlist else {
                    return await player.queue.set(for: selected, using: playlist)
                }

                await player.queue.set(for: selected)

                guard let song = player.currentSong else {
                    return
                }

                player.currentMedia = await player.queue.get(for: selected, using: song)
            }
            .task(id: player.currentSong) {
                guard let song = player.currentSong else {
                    return
                }

                player.currentMedia = await player.queue.get(for: selected, using: song)
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
