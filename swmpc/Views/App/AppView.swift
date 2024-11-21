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

    @State private var selected: MediaType = .album
    @State private var path = NavigationPath()

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                Section("Library") {
                    ForEach(categories) { category in
                        Label(category.type.rawValue, systemImage: category.image)
                            .tag(category.type)
                    }
                }

                Section("Playlists") {}
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
