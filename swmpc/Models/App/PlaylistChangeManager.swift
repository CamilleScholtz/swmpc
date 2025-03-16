//
//  PlaylistChangeManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import Navigator
import SwiftUI

extension NavigationAction {
    @MainActor static var playlistChangeRequired: NavigationAction = .empty
}

// TODO: This does not work with @Observable as of yet. Probably something to do with
// Navigator.
@MainActor
class PlaylistChangeManager: ObservableObject {
    @Published var playlistChangeRequired = false

    init() {
        print("init")
        setupPlaylistChangeHandler()
    }

    private func setupPlaylistChangeHandler() {
        NavigationAction.playlistChangeRequired = .init("playlistChangeRequired") { _ in
            print("fire")
            self.playlistChangeRequired = true
            
            return .pause
        }
    }
}

public extension View {
    func setPlaylistRootModifier() -> some View {
        self.modifier(PlaylistRootModifier())
    }
}

struct PlaylistRootModifier: ViewModifier {
    @Environment(\.navigator) var navigator: Navigator

    @StateObject private var playlistChangeManager = PlaylistChangeManager()

    func body(content: Content) -> some View {
        content
            .environmentObject(playlistChangeManager)
            .alert("Queue Playlist", isPresented: $playlistChangeManager.playlistChangeRequired) {
                Button("Cancel", role: .cancel) {
                    navigator.cancelResume()
                }

                Button("Queue") {
                    Task(priority: .userInitiated) {
                        //playlistService.playlist = playlistService.pendingPlaylist

                        navigator.resume()
                    }
                }
            } message: {
                Text("This will overwrite the current queue.")
//                if let playlist = playlistToQueue {
//                    Text("Are you sure you want to queue playlist ’\(playlist.name)’?")
//                } else {
//                    Text("Are you sure you want to queue the library?")
//                }
            }
    }
}
