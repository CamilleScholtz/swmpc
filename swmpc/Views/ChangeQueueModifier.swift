//
//  ChangeQueueModifier.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SwiftUI

extension View {
    func handleQueueChange() -> some View {
        modifier(ChangeQueueModifier())
    }
}

struct ChangeQueueModifier: ViewModifier {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    @State private var showAlert = false
    @State private var playlistToQueue: Playlist?
    @State private var previousDestination: CategoryDestination?

    func body(content: Content) -> some View {
        content
            .onChange(of: navigator.category) { previous, value in
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

                navigator.reset()
                showAlert = true
            }
            .alert(playlistToQueue == nil ? "Queue Library" : "Queue Playlist \(playlistToQueue!.name)", isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {
                    navigator.category = previousDestination ?? .albums
                }

                AsyncButton("Queue") {
                    try await ConnectionManager.command().loadPlaylist(playlistToQueue)
                    try await mpd.queue.set(using: navigator.category.type, force: true)
                }
            } message: {
                Text("This will overwrite the current queue.")
            }
    }
}
