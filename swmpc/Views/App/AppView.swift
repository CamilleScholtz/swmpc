//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct AppView: View {
    @Environment(Player.self) private var player

    struct Category: Identifiable, Hashable {
        let id = UUID()

        let type: MediaType
        let image: String
    }

    private let categories: [Category] = [
        .init(type: MediaType.album, image: "square.stack"),
        .init(type: MediaType.artist, image: "music.microphone"),
        .init(type: MediaType.song, image: "music.note"),
    ]

    @State private var selected = MediaType.album
    @State private var path = NavigationPath()
    @State private var search = ""

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
                    Label(category.type.rawValue, systemImage: category.image)
                        .tag(category.type)
                }

                Section("Playlists") {
                    ForEach(player.playlists ?? []) { playlist in
                        Label(playlist.name, systemImage: "music.note.list")
                            .tag(playlist)
                    }

                    if editingPlaylist {
                        TextField("Untitled Playlist", text: $playlistName)
                            .focused($playlistFocus)
                            .onSubmit {
                                Task {
                                    try? await CommandManager.shared.createPlaylist(named: playlistName)

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
        } content: {
            ContentView(for: $selected, path: $path)
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
