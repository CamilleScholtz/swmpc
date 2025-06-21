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

    @AppStorage(Setting.simpleMode) var simpleMode = false

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

                    if simpleMode {
                        playlistToQueue = nil
                        showAlert = true
                    } else {
                        Task(priority: .userInitiated) {
                            try? await mpd.database.set(using: navigator.category.type, force: true)
                        }
                    }
                case let .playlist(playlist):
                    guard playlist != mpd.status.playlist else {
                        Task(priority: .userInitiated) {
                            try? await mpd.database.set(using: .song)
                        }

                        return
                    }
                #if os(iOS)
                    default:
                        return
                    #endif
                }

                navigator.reset()
            }
            .alert(playlistToQueue == nil ? "Queue Library" : "Queue Playlist \(playlistToQueue!.name)", isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {
                    navigator.category = previousDestination ?? .albums
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
