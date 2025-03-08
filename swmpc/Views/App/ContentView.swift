//
//  ContentView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import SFSafeSymbols
import SwiftUI

struct ContentView: View {
    @Environment(MPD.self) private var mpd
    @Environment(Router.self) private var router

    @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false

    @State private var isSearching = false
    @State private var isHovering = false

    @State private var showIntelligencePlaylistSheet = false
    @State private var playlistToEdit: Playlist?
    @State private var intelligencePlaylistPrompt = ""

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)
    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)
    private let createIntelligencePlaylistNotification = NotificationCenter.default
        .publisher(for: .createIntelligencePlaylistNotification)

    var body: some View {
        @Bindable var boundRouter = router

        NavigationStack(path: $boundRouter.path) {
            Group {
                if mpd.queue.media.count == 0 {
                    VStack {
                        switch router.category.type {
                        case .playlist:
                            Text("No songs in playlist.")
                                .font(.headline)
                            Text("Add songs to your playlist.")
                                .font(.subheadline)

                            IntelligenceButtonView("Create Playlist using AI")
                                .offset(y: 20)
                                .onTapGesture {
                                    guard isIntelligenceEnabled else {
                                        return
                                    }

                                    NotificationCenter.default.post(name: .createIntelligencePlaylistNotification, object: router.category.playlist)
                                }
                        default:
                            Text("No \(router.category.label.lowercased()) in library.")
                                .font(.headline)

                            Text("Add songs to your library.")
                                .font(.subheadline)
                        }
                    }
                    .offset(y: -60)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            HeaderView(isSearching: $isSearching)
                                .id("top")

                            LazyVStack(alignment: .leading, spacing: 15) {
                                switch router.category.type {
                                case .artist:
                                    ArtistsView()
                                case .song, .playlist:
                                    SongsView()
                                default:
                                    AlbumsView()
                                }
                            }
                            .id(router.category)
                            .padding(.horizontal, 15)
                            .padding(.bottom, 15)
                        }
                        .onReceive(scrollToCurrentNotification) { notification in
                            scrollToCurrent(proxy, animate: notification.object as? Bool ?? true)
                        }
                        .onReceive(startSearchingNotication) { _ in
                            scrollToTop(proxy)

                            isSearching = true
                        }
                    }
                }
            }
            .overlay(LoadingView())
            .ignoresSafeArea()
            .navigationDestination(for: Artist.self) { artist in
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        backButton()
                        ArtistAlbumsView(for: artist)
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                }
                .ignoresSafeArea()
            }
            .navigationDestination(for: Album.self) { album in
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        backButton()
                        AlbumSongsView(for: album)
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                }
                .ignoresSafeArea()
            }
            .onReceive(createIntelligencePlaylistNotification) { notification in
                guard let playlist = notification.object as? Playlist else {
                    return
                }

                playlistToEdit = playlist
                showIntelligencePlaylistSheet = true
            }
            .sheet(isPresented: $showIntelligencePlaylistSheet) {
                IntelligencePlaylistView(showIntelligencePlaylistSheet: $showIntelligencePlaylistSheet, playlistToEdit: $playlistToEdit)
            }
        }
    }

    private func backButton() -> some View {
        Image(systemSymbol: .chevronBackward)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color(.secondarySystemFill) : .clear)
            )
            .padding(.top, 12)
            .animation(.interactiveSpring, value: isHovering)
            .onHover(perform: { value in
                isHovering = value
            })
            .onTapGesture(perform: {
                router.path.removeLast()
            })
    }

    struct LoadingView: View {
        @Environment(MPD.self) private var mpd
        @Environment(Router.self) private var router

        @State private var isLoading = true

        var body: some View {
            ZStack {
                if isLoading {
                    Rectangle()
                        .fill(.background)
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ProgressView()
                }
            }
            .onChange(of: router.category) {
                isLoading = true
            }
            .task(id: mpd.queue.lastUpdated) {
                guard isLoading else {
                    return
                }

                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.interactiveSpring) {
                    isLoading = false
                }
            }
        }
    }

    struct ArtistsView: View {
        @Environment(MPD.self) private var mpd

        @AppStorage(Setting.scrollToCurrent) private var scrollToCurrent = false

        private var artists: [Artist] {
            mpd.queue.media as? [Artist] ?? []
        }

        var body: some View {
            ForEach(artists) { artist in
                ArtistView(for: artist)
            }
            .onChange(of: mpd.status.media as? Artist) { previous, _ in
                if scrollToCurrent {
                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: previous != nil)
                } else {
                    guard previous == nil else {
                        return
                    }

                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
                }
            }
            .task(id: mpd.status.song) {
                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.queue.get(for: song, using: .artist)
            }
        }
    }

    struct ArtistAlbumsView: View {
        @Environment(MPD.self) private var mpd

        private var artist: Artist

        init(for artist: Artist) {
            self.artist = artist
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(artist.name)
                            .font(.system(size: 18))
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .lineLimit(3)

                        Text(artist.albums?.count ?? 0 > 1 ? "\(String(artist.albums!.count)) albums" : "1 album")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 15)

                ForEach(artist.albums ?? []) { album in
                    AlbumView(for: album)
                }
            }
            .onAppear {
                NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
            }
            .task {
                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.queue.get(for: song, using: .album)
            }
        }
    }

    struct AlbumsView: View {
        @Environment(MPD.self) private var mpd

        @AppStorage(Setting.scrollToCurrent) private var scrollToCurrent = false

        private var albums: [Album] {
            mpd.queue.media as? [Album] ?? []
        }

        var body: some View {
            ForEach(albums) { album in
                AlbumView(for: album)
            }
            .onChange(of: mpd.status.media as? Album) { previous, _ in
                if scrollToCurrent {
                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: previous != nil)
                } else {
                    guard previous == nil else {
                        return
                    }

                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
                }
            }
            .task(id: mpd.status.song) {
                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.queue.get(for: song, using: .album)
            }
        }
    }

    struct AlbumSongsView: View {
        @Environment(MPD.self) private var mpd
        @Environment(Router.self) private var router
        @Environment(\.colorScheme) private var colorScheme

        init(for album: Album) {
            _album = State(initialValue: album)
        }

        @State private var album: Album
        @State private var artwork: NSImage?
        @State private var songs: [Int: [Song]]?

        @State private var isHovering = false

        var body: some View {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 15) {
                    if artwork != nil {
                        ZStack {
                            ZStack(alignment: .bottom) {
                                ArtworkView(image: $artwork)
                                    .frame(width: 80)
                                    .blur(radius: 17)
                                    .offset(y: 7)
                                    .saturation(1.5)
                                    .blendMode(colorScheme == .dark ? .softLight : .normal)
                                    .opacity(0.5)

                                ArtworkView(image: $artwork)
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                                    .frame(width: 100)
                                    .overlay(
                                        ZStack(alignment: .bottomLeading) {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 100)
                                                .mask(
                                                    LinearGradient(
                                                        gradient: Gradient(stops: [
                                                            .init(color: .black, location: 0.3),
                                                            .init(color: .black.opacity(0), location: 1.0),
                                                        ]),
                                                        startPoint: .bottom,
                                                        endPoint: .top
                                                    )
                                                )

                                            HStack(spacing: 5) {
                                                Image(systemSymbol: .playFill)
                                                Text("Playing")
                                            }

                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(.white)
                                            .cornerRadius(100)
                                            .padding(10)
                                        }
                                        .opacity(mpd.status.media?.id == album.id ? 1 : 0)
                                        .animation(.interactiveSpring, value: mpd.status.media?.id == album.id)
                                    )
                            }

                            if isHovering, mpd.status.media?.id != album.id {
                                ZStack {
                                    Circle()
                                        .fill(.accent)
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 60, height: 60)

                                    Image(systemSymbol: .playFill)
                                        .font(.title)
                                        .foregroundColor(.white)
                                }
                                .transition(.opacity)
                            }
                        }
                        .onHover(perform: { value in
                            withAnimation(.interactiveSpring) {
                                isHovering = value
                            }
                        })
                        .onTapGesture(perform: {
                            Task(priority: .userInitiated) {
                                if mpd.status.media?.id != album.id {
                                    try? await ConnectionManager.command().play(album)
                                }
                            }
                        })
                        .contextMenu {
                            Button("Add Album to Favorites") {
                                Task {
                                    try? await ConnectionManager.command().addToFavorites(songs: songs?.values.flatMap(\.self) ?? [])
                                }
                            }

                            if let playlists = (mpd.status.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.queue.playlists {
                                Menu("Add Album to Playlist") {
                                    ForEach(playlists) { playlist in
                                        Button(playlist.name) {
                                            Task {
                                                try? await ConnectionManager.command().addToPlaylist(playlist, songs: songs?.values.flatMap(\.self) ?? [])
                                            }
                                        }
                                    }
                                }

                                if let playlist = mpd.status.playlist {
                                    Button("Remove Album from Playlist") {
                                        Task {
                                            try? await ConnectionManager.command().removeFromPlaylist(playlist, songs: songs?.values.flatMap(\.self) ?? [])
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(album.title)
                            .font(.system(size: 18))
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .lineLimit(3)

                        Text(album.artist)
                            .font(.system(size: 12))
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .onTapGesture(perform: {
                                Task(priority: .userInitiated) {
                                    // TODO: Set the type here first
                                    guard let media = try? await mpd.queue.get(for: album, using: .artist) else {
                                        return
                                    }

                                    router.path.append(media)
                                }
                            })

                        if let songs {
                            let flat = songs.values.flatMap(\.self)

                            Text((flat.count > 1 ? "\(String(flat.count)) songs" : "1 song")
                                + " • "
                                + (flat.reduce(0) { $0 + $1.duration }.humanTimeString))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.bottom, 15)

                if let songs {
                    ForEach(songs.keys.sorted(), id: \.self) { disc in
                        VStack(alignment: .leading, spacing: 15) {
                            if songs.keys.count > 1 {
                                Text("Disc \(String(disc))")
                                    .font(.headline)
                                    .padding(.top, disc == songs.keys.sorted().first ? 0 : 10)
                            }

                            ForEach(songs[disc] ?? []) { song in
                                SongView(for: song)
                            }
                        }
                    }
                }
            }
            .task {
                async let artworkDataTask = ArtworkManager.shared.get(for: album, shouldCache: true)
                async let songsTask = ConnectionManager.command().getSongs(for: album)

                artwork = await NSImage(data: (try? artworkDataTask) ?? Data())
                songs = await Dictionary(grouping: (try? songsTask) ?? [], by: { $0.disc })
            }
        }
    }

    struct SongsView: View {
        @Environment(MPD.self) private var mpd

        @AppStorage(Setting.scrollToCurrent) private var scrollToCurrent = false

        private var songs: [Song] {
            mpd.queue.media as? [Song] ?? []
        }

        var body: some View {
            ForEach(songs) { song in
                SongView(for: song)
            }
            .onChange(of: mpd.status.media as? Song) { previous, _ in
                if scrollToCurrent {
                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: previous != nil)
                } else {
                    guard previous == nil else {
                        return
                    }

                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
                }
            }
            .task(id: mpd.status.song) {
                guard let song = mpd.status.song else {
                    return
                }

                mpd.status.media = try? await mpd.queue.get(for: song, using: .song)
            }
        }
    }

    struct HeaderView: View {
        @Environment(MPD.self) private var mpd
        @Environment(Router.self) private var router

        @Binding var isSearching: Bool

        @State private var isHovering = false
        @State private var query = ""

        @FocusState private var isFocused: Bool

        var body: some View {
            HStack {
                if !isSearching {
                    Text(router.category.label)
                        .font(.headline)

                    Spacer()

                    Image(systemSymbol: .magnifyingglass)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isHovering ? Color(.secondarySystemFill) : .clear)
                        )
                        .animation(.interactiveSpring, value: isHovering)
                        .onHover(perform: { value in
                            isHovering = value
                        })
                        .onTapGesture(perform: {
                            isSearching = true
                        })
                } else {
                    TextField("Search", text: $query)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.secondarySystemFill))
                        .cornerRadius(4)
                        .disableAutocorrection(true)
                        .focused($isFocused)
                        .onAppear {
                            query = ""
                            isFocused = true
                        }
                        .onDisappear {
                            query = ""
                            isFocused = false
                        }

                    Image(systemSymbol: .xmarkCircle)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isHovering ? Color(.secondarySystemFill) : .clear)
                        )
                        .animation(.interactiveSpring, value: isHovering)
                        .onHover(perform: { value in
                            isHovering = value
                        })
                        .onTapGesture(perform: {
                            isSearching = false
                        })
                }
            }
            .frame(height: 50 - 7.5)
            .padding(.horizontal, 15)
            .padding(.top, 7.5)
            .onChange(of: router.category) {
                isSearching = false
            }
            .task(id: isSearching) {
                if !isSearching {
                    query = ""
                    mpd.queue.results = nil
                }
            }
            .task(id: query) {
                guard isSearching else {
                    return
                }

                if query.isEmpty {
                    mpd.queue.results = nil
                    return
                }

                try? await mpd.queue.search(for: query)
            }
        }
    }

    struct ArtistView: View {
        @Environment(MPD.self) private var mpd
        @Environment(Router.self) private var router

        private let artist: Artist

        init(for artist: Artist) {
            self.artist = artist
        }

        var body: some View {
            HStack(spacing: 15) {
                let initials = artist.name.split(separator: " ")
                    .prefix(2)
                    .compactMap(\.first)
                    .map { String($0) }
                    .joined()
                    .uppercased()

                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(.secondarySystemFill), location: 0.0),
                            .init(color: Color(.secondarySystemFill).opacity(0.7), location: 1.0),
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 18))
                            .fontDesign(.rounded)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    )

                VStack(alignment: .leading) {
                    Text(artist.name)
                        .font(.headline)
                        .foregroundColor(mpd.status.media?.id == artist.id ? .accentColor : .primary)
                        .lineLimit(2)
                    Text(artist.albums?.count ?? 0 == 1 ? "1 album" : "\(artist.albums!.count) albums")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(artist)
            .contentShape(Rectangle())
            .onTapGesture(perform: {
                router.path.append(artist)
            })
        }
    }

    struct AlbumView: View {
        @Environment(MPD.self) private var mpd
        @Environment(Router.self) private var router

        private let album: Album

        init(for album: Album) {
            self.album = album
        }

        @State private var artwork: NSImage?
        @State private var isHovering = false
        @State private var isHoveringArtwork = false

        var body: some View {
            HStack(spacing: 15) {
                ZStack {
                    ArtworkView(image: $artwork)
                        .cornerRadius(5)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                        .frame(width: 60)

                    if isHovering {
                        ZStack {
                            if isHoveringArtwork {
                                Circle()
                                    .fill(.accent)
                                    .frame(width: 40, height: 40)
                            }
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)

                            Image(systemSymbol: .playFill)
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .transition(.opacity)
                    }
                }
                .onHover(perform: { value in
                    withAnimation(.interactiveSpring) {
                        isHoveringArtwork = value
                    }
                })
                .onTapGesture {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().play(album)
                    }
                }

                VStack(alignment: .leading) {
                    Text(album.title)
                        .font(.headline)
                        .foregroundColor(mpd.status.media?.id == album.id ? .accentColor : .primary)
                        .lineLimit(2)
                    Text(album.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(album)
            .onHover(perform: { value in
                withAnimation(.interactiveSpring) {
                    isHovering = value
                }
            })
            .task(id: album, priority: .high) {
                // TODO: This can probably be made even a little snappier.
                try? await Task.sleep(nanoseconds: 48_000_000)
                guard !Task.isCancelled else {
                    return
                }

                guard let data = try? await ArtworkManager.shared.get(for: album) else {
                    return
                }

                artwork = NSImage(data: data)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: {
                router.path.append(album)
            })
            .contextMenu {
                Button("Add Album to Favorites") {
                    Task {
                        try? await ConnectionManager.command().addToFavorites(songs: ConnectionManager.command().getSongs(for: album))
                    }
                }

                if let playlists = (mpd.status.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.queue.playlists {
                    Menu("Add Album to Playlist") {
                        ForEach(playlists) { playlist in
                            Button(playlist.name) {
                                Task {
                                    try? await ConnectionManager.command().addToPlaylist(playlist, songs: ConnectionManager.command().getSongs(for: album))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    struct SongView: View {
        @Environment(MPD.self) private var mpd
        @Environment(Router.self) private var router

        private let song: Song

        init(for song: Song) {
            self.song = song
        }

        @State private var isHovering = false

        var body: some View {
            HStack(spacing: 15) {
                Group {
                    if !isHovering, mpd.status.song != song {
                        Text(String(song.track))
                            .font(.title3)
                            .fontWeight(.regular)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    } else {
                        if mpd.status.song == song {
                            WaveView()
                        } else {
                            Image(systemSymbol: .playFill)
                                .font(.title3)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .frame(width: 20)

                VStack(alignment: .leading) {
                    Text(song.title)
                        .font(.headline)
                        .foregroundColor(mpd.status.song == song ? .accentColor : .primary)
                        .lineLimit(2)

                    Text((song.artist) + " • " + song.duration.timeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(song)
            .contentShape(Rectangle())
            .onHover(perform: { value in
                isHovering = value
            })
            .onTapGesture(perform: {
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().play(song)
                }
            })
            .contextMenu {
                if mpd.status.playlist?.name != "Favorites" {
                    Button("Add Song to Favorites") {
                        Task {
                            try? await ConnectionManager.command().addToFavorites(songs: [song])
                        }
                    }
                }

                if let playlists = (mpd.status.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.queue.playlists {
                    Menu("Add Song to Playlist") {
                        ForEach(playlists) { playlist in
                            Button(playlist.name) {
                                Task {
                                    try? await ConnectionManager.command().addToPlaylist(playlist, songs: [song])
                                }
                            }
                        }
                    }

                    if let playlist = mpd.status.playlist {
                        Divider()

                        if mpd.status.playlist?.name == "Favorites" {
                            Button("Remove Song from Favorites") {
                                Task {
                                    try? await ConnectionManager.command().removeFromFavorites(songs: [song])
                                }
                            }
                        } else {
                            Button("Remove Song from Playlist") {
                                Task {
                                    try? await ConnectionManager.command().removeFromPlaylist(playlist, songs: [song])
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    struct ArtworkView: View {
        @Binding var image: NSImage?

        var body: some View {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill).opacity(0.3))
                    .aspectRatio(contentMode: .fit)
                    .scaledToFill()
            }
        }
    }

    struct WaveView: View {
        @Environment(MPD.self) private var mpd

        @State private var isAnimating = false

        var body: some View {
            let isPlaying = mpd.status.isPlaying

            HStack(spacing: 1.5) {
                bar(low: 0.4)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.5).repeatForever() : .linear(duration: 0.5), value: isAnimating)
                bar(low: 0.3)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.2).repeatForever() : .linear(duration: 0.5), value: isAnimating)
                bar(low: 0.5)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.0).repeatForever() : .linear(duration: 0.5), value: isAnimating)
                bar(low: 0.3)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.7).repeatForever() : .linear(duration: 0.5), value: isAnimating)
                bar(low: 0.5)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.0).repeatForever() : .linear(duration: 0.5), value: isAnimating)
            }
            .onAppear {
                isAnimating = isPlaying
            }
            .onDisappear {
                isAnimating = false
            }
            .onChange(of: isPlaying) { _, value in
                isAnimating = value
            }
        }

        private func bar(low: CGFloat = 0.0, high: CGFloat = 1.0) -> some View {
            RoundedRectangle(cornerRadius: 2)
                .fill(.secondary)
                .frame(width: 2, height: (isAnimating ? high : low) * 12)
        }
    }

    struct IntelligencePlaylistView: View {
        @Environment(MPD.self) private var mpd

        @Binding var showIntelligencePlaylistSheet: Bool
        @Binding var playlistToEdit: Playlist?

        private let loadingSentences = [
            "Analyzing music preferences…",
            "Matching tracks to vibe…",
            "Curating playlist…",
            "Cross-referencing mood with melodies…",
            "Syncing sounds with taste…",
            "Selecting ideal tracks…",
            "Calculating song sequence…",
            "Mixing music…",
            "Identifying harmonious tracks…",
            "Checking for duplicates…",
            "Cloud-sourcing songs…",
            "Shuffling songs…",
            "Scanning for similar tracks…",
            "Filtering out noise…",
            "Sorting songs by genre…",
            "Recommending tracks…",
            "Analyzing beats per minute…",
            "Rating songs…",
            "Consulting /mu/…",
            "Analyzing song lyrics…",
            "Checking for explicit content…",
            "Scanning for hidden gems…",
            "Waiting for inspiration…",
            "Calculating song popularity…",
            "Analyzing waveform…",
        ]

        private let suggestions = [
            "Love Songs",
            "Turkish Music",
            "Asian Music",
            "Russian Music",
            "Baroque Pop-Punk",
            "Spontaneous Jazz",
            "Chill vibes",
            "Workout Tunes",
            "Party Mix",
            "Study Beats",
            "Relaxing Music",
            "Post-Apocalyptic Polka",
            "Gnome Music",
            "Video Game Soundtracks",
            "Classical Music",
        ]

        init(showIntelligencePlaylistSheet: Binding<Bool>, playlistToEdit: Binding<Playlist?>) {
            _showIntelligencePlaylistSheet = showIntelligencePlaylistSheet
            _playlistToEdit = playlistToEdit

            _loadingSentence = State(initialValue: loadingSentences.randomElement()!)
            _suggestion = State(initialValue: suggestions.randomElement()!)
        }

        @State private var prompt = ""
        @State private var isLoading = false

        @State private var loadingSentence: String
        @State private var suggestion: String

        @FocusState private var isFocused: Bool

        var body: some View {
            VStack(spacing: 30) {
                if isLoading {
                    IntelligenceSparklesView()
                        .font(.system(size: 40))

                    Text(loadingSentence)
                        .padding(.vertical, 5)
                        .font(.subheadline)
                        .onReceive(
                            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
                        ) { _ in
                            loadingSentence = loadingSentences.randomElement()!
                        }
                } else {
                    Text("I want to listen to…")
                        .font(.headline)

                    // XXX: So this is super hacky, but we create this invisible
                    // TextField that draws the focus, because `.focused` for
                    // some reason does not work.
                    TextField("", text: .constant(""))
                        .textFieldStyle(.plain)
                        .frame(width: 0, height: 0)

                    TextField(suggestion, text: $prompt)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.accent)
                        .cornerRadius(100)
                        .multilineTextAlignment(.center)
                        .disableAutocorrection(true)
                        .focused($isFocused)
                        .offset(y: -30)
                        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()
                        ) { _ in
                            guard !isFocused else {
                                return
                            }

                            suggestion = suggestions.randomElement()!
                        }
                        .onChange(of: isFocused) { _, value in
                            guard value else {
                                return
                            }

                            suggestion = ""
                        }
                        .onAppear {
                            isFocused = false
                        }

                    HStack {
                        Button("Cancel", role: .cancel) {
                            playlistToEdit = nil
                            showIntelligencePlaylistSheet = false
                        }
                        .keyboardShortcut(.cancelAction)

                        Button("Create") {
                            Task(priority: .userInitiated) {
                                isLoading = true

                                try? await IntelligenceManager.shared.fillPlaylist(using: playlistToEdit!, prompt: prompt)
                                try? await mpd.queue.set(using: .playlist, force: true)

                                isLoading = false
                                playlistToEdit = nil
                                showIntelligencePlaylistSheet = false
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .offset(y: -30)
                }
            }
            .frame(width: 300)
            .padding(20)
        }
    }

    struct IntelligenceSparklesView: View {
        @State private var offset: CGFloat = 0

        private let colors: [Color] = [.yellow, .orange, .brown, .orange, .yellow]

        var body: some View {
            Image(systemSymbol: .sparkles)
                .overlay(
                    LinearGradient(
                        colors: colors,
                        startPoint: UnitPoint(x: offset, y: 0),
                        endPoint: UnitPoint(x: CGFloat(colors.count) + offset, y: 0)
                    )
                    .onAppear {
                        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                            offset = -CGFloat(colors.count - 1)
                        }
                    }
                )
                .mask(Image(systemSymbol: .sparkles))
        }
    }

    struct IntelligenceButtonView: View {
        @AppStorage(Setting.isIntelligenceEnabled) var isIntelligenceEnabled = false

        var title: String

        init(_ title: String) {
            self.title = title
        }

        @State private var isHovering = false

        var body: some View {
            VStack {
                HStack {
                    IntelligenceSparklesView()
                    Text(title)
                }
                .padding(8)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                )
                .scaleEffect(isHovering ? 1.05 : 1)
                .animation(.interactiveSpring, value: isHovering)
                .opacity(isIntelligenceEnabled ? 1 : 0.7)
                .onHover(perform: { value in
                    guard isIntelligenceEnabled else {
                        return
                    }

                    isHovering = value
                })

                if !isIntelligenceEnabled {
                    Text("Enable AI features in settings to use this feature.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .offset(y: 10)
                }
            }
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, animate: Bool = true) {
        guard let media = mpd.status.media else {
            return
        }

        if animate {
            withAnimation {
                proxy.scrollTo(media, anchor: .center)
            }
        } else {
            proxy.scrollTo(media, anchor: .center)
        }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy, animate: Bool = true) {
        if animate {
            withAnimation {
                proxy.scrollTo("top", anchor: .center)
            }
        } else {
            proxy.scrollTo("top", anchor: .center)
        }
    }
}
