//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct AppView: View {
    @Environment(MPD.self) private var mpd

    private let categories: [Category]

    @State private var category: Category
    @State private var path = NavigationPath()
    @State private var queue: [any Mediable]?
    @State private var query = ""

    @State private var showError = false

    init() {
        categories = [
            .init(type: MediaType.album, playlist: nil, label: "Albums", image: .squareStack),
            .init(type: MediaType.artist, playlist: nil, label: "Artists", image: .musicMic),
            .init(type: MediaType.song, playlist: nil, label: "Songs", image: .musicNote),
        ]

        category = categories.first!
    }

    var body: some View {
        Group {
            if mpd.status.state == nil {
                NavigationSplitView {
                    List {
                        Text("swmpc")
                            .font(.system(size: 18))
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .padding(.bottom, 15)
                    }
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
                .task(priority: .medium) {
                    try? await Task.sleep(for: .seconds(2))

                    guard !Task.isCancelled else {
                        return
                    }

                    showError = true
                }
            } else {
                NavigationSplitView {
                    SidebarView(category: $category, queue: $queue, query: $query)
                } content: {
                    ContentView(category: $category, queue: $queue, query: $query, path: $path)
                        .navigationBarBackButtonHidden()
                        .navigationSplitViewColumnWidth(310)
                } detail: {
                    ViewThatFits {
                        DetailView(path: $path)
                    }
                    .padding(60)
                }
                .task {
                    if category.type == .playlist {
                        guard let playlist = category.playlist else {
                            return
                        }

                        queue = try? await ConnectionManager.command().getPlaylist(playlist)
                    } else {
                        queue = mpd.queue.media
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
