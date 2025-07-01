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
                    print("previous")
                    return
                }

                previousDestination = previous

                switch value {
                case .albums, .artists, .songs:
                    guard mpd.status.playlist != nil else {
                        Task(priority: .userInitiated) {
                            try? await mpd.database.set(using: value.type)
                        }

                        return
                    }

                    Task(priority: .userInitiated) {
                        try? await mpd.database.set(using: navigator.category.type, force: true)
                    }
                default:
                    return
                }

                navigator.reset()
            }
            .alert(playlistToQueue == nil ? "Queue Library" : "Queue Playlist \(playlistToQueue!.name)", isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {
                    navigator.category = previousDestination ?? .albums
                    showAlert = false
                }

                AsyncButton("Queue") {
                    if let playlist = playlistToQueue {
                        try await ConnectionManager.command().loadPlaylist(playlist)
                    } else {
                        try await ConnectionManager.command().loadPlaylist(nil)
                    }

                    try await mpd.database.set(using: navigator.category.type, force: true)
                }
            } message: {
                Text("This will overwrite the current queue.")
            }
    }
}
