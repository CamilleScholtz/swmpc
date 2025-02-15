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
    @State private var queue: [any Mediable]?
    @State private var query = ""

    @State private var showError = false

    var body: some View {
        Group {
            if mpd.status.state == nil {
                NavigationSplitView {
                    SidebarView(selected: $selected, queue: $queue, query: $query)
                } detail: {
                    ProgressView()
                        .offset(y: -20)

                    VStack {
                        Text("Could not establish connection to MPD.")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Please check your configuration and server.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .opacity(showError ? 1 : 0)
                    .animation(.spring, value: showError)
                }
                .task(priority: .background) {
                    try? await Task.sleep(for: .seconds(2))
                    showError = true
                }
            } else {
                NavigationSplitView {
                    SidebarView(selected: $selected, queue: $queue, query: $query)
                } content: {
                    ContentView(category: $selected, queue: $queue, query: $query, path: $path)
                        .navigationBarBackButtonHidden()
                        .navigationSplitViewColumnWidth(310)
                } detail: {
                    ViewThatFits {
                        DetailView(path: $path)
                    }
                    .padding(60)
                }
                .onAppear {
                    Task {
                        if selected.type == .playlist {
                            guard let playlist = selected.playlist else {
                                return
                            }

                            queue = try? await ConnectionManager.command.getPlaylist(playlist)
                        } else {
                            queue = mpd.queue.media
                        }
                    }
                }
            }
        }
        .background(.background)
        .toolbar {
            Color.clear
        }
    }
}
