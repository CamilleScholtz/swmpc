//
//  ChangeQueueModifier.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

extension View {
    func handleQueueChange(destination: Binding<SidebarDestination>) -> some View {
        modifier(ChangeQueueModifier(destination: destination))
    }
}

struct ChangeQueueModifier: ViewModifier {
    @Environment(MPD.self) private var mpd
    @Environment(PathManager.self) private var pathManager

    @Binding var destination: SidebarDestination

    @State private var previousDestination: SidebarDestination?
    @State private var navigationPaused = false
    
    @State private var showAlert = false
    @State private var playlistToQueue: Playlist?

    func body(content: Content) -> some View {
        content
            .onChange(of: destination) { previous, value in
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

                pathManager.popToRoot(for: value)
                navigationPaused = true

                showAlert = true
            }
            .alert(playlistToQueue == nil ? "Queue Library" : "Queue Playlist \(playlistToQueue!.name)", isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {
                    navigationPaused = false
                    destination = previousDestination ?? .albums
                }

                Button("Queue") {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().loadPlaylist(playlistToQueue)
                        try? await mpd.queue.set(using: destination.type, force: true)

                        navigationPaused = false
                    }
                }
            } message: {
                Text("This will overwrite the current queue.")
            }
    }
}
