//
//  CategoryDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI
import SwiftUIIntrospect

struct CategoryDestinationView: View {
    @Environment(MPD.self) private var mpd

    let destination: CategoryDestination

    @State private var isLoadingPlaylist = true
    @State private var playlistSongs: [Song]?

    var body: some View {
        switch destination {
        #if os(iOS)
            case .playlists:
                PlaylistsView()
            case .settings:
                SettingsView()
        #endif
        case let .playlist(playlist):
            Group {
                if isLoadingPlaylist {
                    ZStack {
                        Rectangle()
                            .fill(.background)
                            .ignoresSafeArea()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        ProgressView()
                    }
                } else if playlistSongs == nil || playlistSongs!.isEmpty {
                    EmptyCategoryView(destination: destination)
                } else {
                    CategoryView(destination: destination)
                }
            }
            .task(id: playlist) {
                isLoadingPlaylist = true
                playlistSongs = try? await ConnectionManager.command().getSongs(from: .playlist(playlist))

                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else {
                    return
                }

                isLoadingPlaylist = false
            }
        default:
            if mpd.database.internalMedia.isEmpty {
                EmptyCategoryView(destination: destination)
            } else {
                CategoryView(destination: destination)
            }
        }
    }
}

struct EmptyCategoryView: View {
    @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false

    let destination: CategoryDestination

    @State private var showIntelligencePlaylistSheet = false
    @State private var playlistToEdit: Playlist?
    @State private var intelligencePlaylistPrompt = ""

    private let fillIntelligencePlaylistNotification = NotificationCenter.default
        .publisher(for: .fillIntelligencePlaylistNotification)

    var body: some View {
        VStack {
            switch destination {
            case .albums, .artists, .songs:
                Text("No \(String(localized: destination.label).lowercased()) in library.")
                    .font(.headline)

                Text("Add songs to your library.")
                    .font(.subheadline)
            case let .playlist(playlist):
                Text("No songs in playlist.")
                    .font(.headline)
                Text("Add songs to your playlist.")
                    .font(.subheadline)

                IntelligenceButtonView(using: playlist)
                    .offset(y: 20)
            #if os(iOS)
                default:
                    EmptyView()
            #endif
            }
        }
        .offset(y: -20)
        .onReceive(fillIntelligencePlaylistNotification) { notification in
            guard let playlist = notification.object as? Playlist else {
                return
            }

            playlistToEdit = playlist
            showIntelligencePlaylistSheet = true
        }
        .sheet(isPresented: $showIntelligencePlaylistSheet) {
            IntelligenceView(target: .playlist($playlistToEdit), showSheet: $showIntelligencePlaylistSheet)
        }
    }
}

struct CategoryView: View {
    @Environment(MPD.self) private var mpd

    let destination: CategoryDestination

    #if os(macOS)
        // NOTE: Kind of hacky. See https://github.com/feedback-assistant/reports/issues/651
        private let rowHeight: CGFloat

        init(destination: CategoryDestination) {
            self.destination = destination

            rowHeight = switch destination {
            case .albums: 50 + 15
            case .artists: 50 + 15
            case .songs, .playlist: 31.5 + 15
            }
        }
    #endif

    #if os(iOS)
        @State private var scrollView: UIScrollView?
    #elseif os(macOS)
        @State private var scrollView: NSScrollView?
    #endif

    @State private var isSearching = false

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)
    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    var body: some View {
        List {
            switch destination {
            case .albums:
                MediaView(using: mpd.database, type: .album)
            case .artists:
                MediaView(using: mpd.database, type: .artist)
            case .songs:
                MediaView(using: mpd.database, type: .song)
            case let .playlist(playlist):
                MediaView(for: playlist)
            #if os(iOS)
                default:
                    EmptyView()
            #endif
            }
        }
        .id(destination)
        .listStyle(.plain)
        #if os(macOS)
            .introspect(.list, on: .macOS(.v26)) { tableView in
                DispatchQueue.main.async {
                    scrollView = tableView.enclosingScrollView
                }
            }
        #endif
            .safeAreaBar(edge: .bottom) {
                Text("D")
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaPadding(.bottom, 7.5)
            .contentMargins(.vertical, -7.5, for: .scrollIndicators)
            .onReceive(scrollToCurrentNotification) { notification in
                try? scrollToCurrent(animate: notification.object as? Bool ?? true)
            }
            .onReceive(startSearchingNotication) { _ in
                isSearching = true
            }
            .task(id: destination) {
                // TODO: Maybe also use `.onChange(of: scrollView)` here like in
                // QueuePanelView?
                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.database.get(for: song, using: destination.type)

                for _ in 0 ..< 5 {
                    do {
                        try scrollToCurrent(animate: false)
                        break
                    } catch {
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
            }
            .task(id: mpd.status.song) {
                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.database.get(for: song, using: destination.type)
            }
            .onChange(of: mpd.database.results?.count) { _, value in
                guard value == nil else {
                    return
                }

                try? scrollToCurrent(animate: false)
            }
        #if os(macOS)
            .environment(\.defaultMinListRowHeight, min(rowHeight, 50))
        #endif
    }

    private func scrollToCurrent(animate: Bool = true) throws {
        guard let scrollView,
              let media = mpd.status.media,
              let index = mpd.database.media.firstIndex(where: { $0.url == media.url })
        else {
            throw ViewError.missingData
        }

        #if os(iOS)
//            let rowSpacing: CGFloat = 15
//            let baseRowHeight: CGFloat = switch destination {
//            case .albums, .artists: 50
//            case .songs, .playlist, _: 31.5
//            }
//            let rowHeight = baseRowHeight + rowSpacing
//
//            let rowMidY = (CGFloat(currentIndex) * rowHeight) + (rowHeight / 2)
//            let visibleHeight = scrollView.frame.height
//            let centeredOffset = rowMidY - (visibleHeight / 2)
//
//            scrollView.setContentOffset(
//                CGPoint(x: 0, y: max(0, centeredOffset)),
//                animated: animate,
//            )
        #elseif os(macOS)
            guard let tableView = scrollView.documentView as? NSTableView else {
                throw ViewError.missingData
            }

            tableView.layoutSubtreeIfNeeded()
            scrollView.layoutSubtreeIfNeeded()

            DispatchQueue.main.async {
                let rect = tableView.frameOfCell(atColumn: 0, row: index)
                let y = rect.midY - (scrollView.frame.height / 2)
                let center = NSPoint(x: 0, y: max(0, y))

                if animate {
                    scrollView.contentView.animator().setBoundsOrigin(center)
                } else {
                    scrollView.contentView.setBoundsOrigin(center)
                }
            }
        #endif
    }
}
