//
//  SidebarView.swift
//  swmpc
//
//  Created by Camille Scholtz on 01/31/2025.
//

import Navigator
import SwiftUI

struct SidebarView: View {
    @Environment(MPD.self) private var mpd
    @Environment(Router.self) private var router
    @Environment(\.navigator) private var navigator: Navigator

    @Binding var selectedDestination: SidebarDestination?

    @State private var showQueueAlert = false
    @State private var playlistToQueue: Playlist?

    @State private var showDeleteAlert = false
    @State private var playlistToDelete: Playlist?

    @State private var isRenamingPlaylist = false
    @State private var playlistToRename: Playlist?

    @State private var isCreatingPlaylist = false
    @State private var playlistName = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        List(selection: $selectedDestination) {
            Text("swmpc")
                .font(.system(size: 18))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .padding(.bottom, 15)

            ForEach(SidebarDestination.categories) { category in
                NavigationLink(value: category) {
                    Label(category.label, systemSymbol: category.symbol)
                }
            }

            Section("Playlists") {
                if let playlists = mpd.queue.playlists {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: SidebarDestination.playlist(playlist)) {
                            Label(playlist.name, systemSymbol: .musicNoteList)
                        }
                    }
                }

                //     ForEach(router.playlists) { category in
                //         if isRenamingPlaylist, category.playlist == playlistToRename {
                //             TextField(playlistName, text: $playlistName)
                //                 .focused($isFocused)
                //                 .onChange(of: isFocused) { _, value in
                //                     guard !value else {
                //                         return
                //                     }

                //                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                //                         isRenamingPlaylist = false
                //                         playlistToRename = nil
                //                         playlistName = ""
                //                     }
                //                 }
                //                 .onSubmit {
                //                     Task(priority: .userInitiated) {
                //                         try await ConnectionManager.command().renamePlaylist(category.playlist!, to: playlistName)

                //                         isRenamingPlaylist = false
                //                         playlistToRename = nil
                //                         playlistName = ""
                //                     }
                //                 }
                //         } else {
                //             NavigationLink(value: category) {
                //                 Label(category.label, systemSymbol: category.image)
                //             }
                //             .contextMenu {
                //                 if category.label != "Favorites" {
                //                     Button("Rename Playlist") {
                //                         isRenamingPlaylist = true
                //                         playlistName = category.playlist!.name
                //                         playlistToRename = category.playlist!
                //                         isFocused = true
                //                     }

                //                     Button("Delete Playlist") {
                //                         playlistToDelete = category.playlist
                //                         showDeleteAlert = true
                //                     }
                //                 }
                //             }
                //         }
                //     }

                //     if isCreatingPlaylist {
                //         TextField("Untitled Playlist", text: $playlistName)
                //             .focused($isFocused)
                //             .onChange(of: isFocused) { _, value in
                //                 guard !value else {
                //                     return
                //                 }

                //                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                //                     isCreatingPlaylist = false
                //                     playlistName = ""
                //                 }
                //             }
                //             .onSubmit {
                //                 Task(priority: .userInitiated) {
                //                     try? await ConnectionManager.command().createPlaylist(named: playlistName)

                //                     isCreatingPlaylist = false
                //                     playlistName = ""
                //                 }
                //             }
                //     }

                //     Label("New Playlist", systemSymbol: .plus)
                //         .onTapGesture(perform: {
                //             isCreatingPlaylist = true
                //             isFocused = true
                //         })
            }
        }
        .toolbar(removing: .sidebarToggle)
        .task(id: selectedDestination) {
            guard let selectedDestination else {
                return
            }

            try? await mpd.queue.set(using: selectedDestination.type)
        }
//        .task(id: mpd.status.playlist) {
//            guard let playlist = mpd.status.playlist else {
//                return
//            }
//
//            guard let category = router.playlists.first(where: { $0.playlist?.name == playlist.name }) else {
//                return
//            }
//
//            guard router.category != category else {
//                return
//            }
//
//            router.category = category
//        }
        .alert("Delete Playlist", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                playlistToDelete = nil
                showDeleteAlert = false
            }

            Button("Delete", role: .destructive) {
                guard let playlist = playlistToDelete else {
                    return
                }

                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().removePlaylist(playlist)

                    playlistToDelete = nil
                    showDeleteAlert = false
                }
            }
        } message: {
            if let playlist = playlistToDelete {
                Text("Are you sure you want to delete playlist ’\(playlist.name)’?")
            }
        }
    }
}
