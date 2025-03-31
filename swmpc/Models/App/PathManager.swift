//
//  PathManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 01/04/2025.
//

import SwiftUI

@Observable
class PathManager {
    #if os(iOS)
        var albumsPath = NavigationPath()
        var artistsPath = NavigationPath()
        var songsPath = NavigationPath()
        var playlistsPath = NavigationPath()
        var settingsPath = NavigationPath()

        func path(for destination: SidebarDestination) -> Binding<NavigationPath> {
            switch destination {
            case .albums:
                Binding(get: { self.albumsPath }, set: { self.albumsPath = $0 })
            case .artists:
                Binding(get: { self.artistsPath }, set: { self.artistsPath = $0 })
            case .songs:
                Binding(get: { self.songsPath }, set: { self.songsPath = $0 })
            case .playlist:
                Binding(get: { self.playlistsPath }, set: { self.playlistsPath = $0 })
            case .playlists:
                Binding(get: { self.playlistsPath }, set: { self.playlistsPath = $0 })
            case .settings:
                Binding(get: { self.settingsPath }, set: { self.settingsPath = $0 })
            }
        }

    #elseif os(macOS)
        var contentPath = NavigationPath()
    #endif

    func navigate(to destination: ContentDestination, from context: SidebarDestination) {
        #if os(iOS)
            path(for: context).wrappedValue.append(destination)
        #elseif os(macOS)
            contentPath.append(destination)
        #endif
    }

    func back(from context: SidebarDestination) {
        #if os(iOS)
            if !path(for: context).wrappedValue.isEmpty {
                path(for: context).wrappedValue.removeLast()
            }
        #elseif os(macOS)
            if !contentPath.isEmpty {
                contentPath.removeLast()
            }
        #endif
    }

    func popToRoot(for context: SidebarDestination) {
        #if os(iOS)
            path(for: context).wrappedValue = NavigationPath()
        #elseif os(macOS)
            contentPath = NavigationPath()
        #endif
    }
}
