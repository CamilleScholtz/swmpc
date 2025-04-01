//
//  ChangeQueueModifier.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

extension View {
    func handleQueueChange() -> some View {
        modifier(ChangeQueueModifier())
    }
}

struct ChangeQueueModifier: ViewModifier {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigation

    @State private var previousDestination: CategoryDestination?
    @State private var navigationPaused = false
    
    @State private var showAlert = false
    @State private var playlistToQueue: Playlist?

    func body(content: Content) -> some View {
        content
            .onChange(of: navigation.categoryDestination) { previous, value in
                guard previous != value else {
                    return
                }

                previousDestination = previous

                switch value {
                case .albums, .artists, .songs:
                    guard mpd.status.playlist != nil else {
                        Task(priority: .userInitiated) {
                            try? await mpd.queue.set(using: value.type)
                        }

                        return
                    }

                    playlistToQueue = nil
                case let .playlist(playlist):
                    guard playlist != mpd.status.playlist else {
                        Task(priority: .userInitiated) {
                            try? await mpd.queue.set(using: value.type)
                        }

                        return
                    }

                    playlistToQueue = playlist
                #if os(iOS)
                    default:
                        return
                    #endif
                }

                navigation.path = NavigationPath()
                navigationPaused = true

                showAlert = true
            }
            .alert(playlistToQueue == nil ? "Queue Library" : "Queue Playlist \(playlistToQueue!.name)", isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {
                    navigationPaused = false
                    navigation.categoryDestination = previousDestination ?? .albums
                }

                Button("Queue") {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().loadPlaylist(playlistToQueue)
                        try? await mpd.queue.set(using: navigation.categoryDestination.type, force: true)

                        navigationPaused = false
                    }
                }
            } message: {
                Text("This will overwrite the current queue.")
            }
    }
}
