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

    @Binding var category: Category
    @Binding var queue: [any Mediable]?
    @Binding var query: String
    @Binding var path: NavigationPath

    @State private var isSearching = false
    @State private var isHovering = false

    private let scrollToCurrentNotifcation = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)
    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    HeaderView(category: $category, isSearching: $isSearching, query: $query)
                        .id("top")

                    LazyVStack(alignment: .leading, spacing: 15) {
                        switch mpd.queue.type {
                        case .artist:
                            ArtistsView(queue: $queue, path: $path)
                        case .song, .playlist:
                            SongsView(category: $category, queue: $queue)
                        default:
                            AlbumsView(queue: $queue, path: $path)
                        }
                    }
                    .id(mpd.queue.type)
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                }
                .onReceive(scrollToCurrentNotifcation) { notification in
                    scrollToCurrent(proxy, animate: notification.object as? Bool ?? true)
                }
                .onReceive(startSearchingNotication) { _ in
                    scrollToTop(proxy)

                    isSearching = true
                }
            }
            .overlay(LoadingView(category: $category))
            .ignoresSafeArea()
            .navigationDestination(for: Artist.self) { artist in
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        backButton()
                        ArtistAlbumsView(for: artist, path: $path)
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
                        AlbumSongsView(for: album, category: $category, path: $path)
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                }
                .ignoresSafeArea()
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
                path.removeLast()
            })
    }

    struct LoadingView: View {
        @Environment(MPD.self) private var mpd

        @Binding var category: Category

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
            .onChange(of: category) {
                isLoading = true
            }
            .task(id: mpd.queue.media.count) {
                guard isLoading, mpd.queue.media.count != 0 else {
                    return
                }

                NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)

                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.interactiveSpring) {
                    isLoading = false
                }
            }
        }
    }

    struct ArtistsView: View {
        @Environment(MPD.self) private var mpd

        @Binding var queue: [any Mediable]?
        @Binding var path: NavigationPath

        private var artists: [Artist] {
            queue as? [Artist] ?? []
        }

        var body: some View {
            ForEach(artists) { artist in
                ArtistView(for: artist, path: $path)
            }
        }
    }

    struct ArtistAlbumsView: View {
        @Environment(MPD.self) private var mpd

        private var artist: Artist

        init(for artist: Artist, path: Binding<NavigationPath>) {
            self.artist = artist
            _path = path
        }

        @Binding var path: NavigationPath

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
                    AlbumView(for: album, path: $path)
                }
            }
        }
    }

    struct AlbumsView: View {
        @Environment(MPD.self) private var mpd

        @Binding var queue: [any Mediable]?
        @Binding var path: NavigationPath

        private var albums: [Album] {
            queue as? [Album] ?? []
        }

        var body: some View {
            ForEach(albums) { album in
                AlbumView(for: album, path: $path)
            }
        }
    }

    struct AlbumSongsView: View {
        @Environment(MPD.self) private var mpd
        @Environment(\.colorScheme) var colorScheme

        init(for album: Album, category: Binding<Category>, path: Binding<NavigationPath>) {
            _album = State(initialValue: album)
            _category = category
            _path = path
        }

        @Binding var category: Category
        @Binding var path: NavigationPath

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

                            if let playlists = (mpd.queue.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.queue.playlist }) : mpd.queue.playlists {
                                Menu("Add Album to Playlist") {
                                    ForEach(playlists) { playlist in
                                        Button(playlist.name) {
                                            Task {
                                                try? await ConnectionManager.command().addToPlaylist(playlist, songs: songs?.values.flatMap(\.self) ?? [])
                                            }
                                        }
                                    }
                                }

                                if let playlist = mpd.queue.playlist {
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
                                    guard let media = try? await mpd.queue.get(for: .artist, using: album) else {
                                        return
                                    }

                                    path.append(media)
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
                                SongView(for: song, category: $category)
                            }
                        }
                    }
                }
            }
            .task {
                async let artworkDataTask = ArtworkManager.shared.get(using: album.url, shouldCache: true)
                async let songsTask = ConnectionManager.command().getSongs(for: album)

                artwork = await NSImage(data: (try? artworkDataTask) ?? Data())
                songs = await Dictionary(grouping: (try? songsTask) ?? [], by: { $0.disc })
            }
        }
    }

    struct SongsView: View {
        @Environment(MPD.self) private var mpd

        @Binding var category: Category
        @Binding var queue: [any Mediable]?

        private var songs: [Song] {
            queue as? [Song] ?? []
        }

        var body: some View {
            ForEach(songs) { song in
                SongView(for: song, category: $category)
            }
        }
    }

    struct HeaderView: View {
        @Environment(MPD.self) private var mpd

        @Binding var category: Category
        @Binding var isSearching: Bool
        @Binding var query: String

        @State private var isHovering = false

        @FocusState private var isFocused: Bool

        var body: some View {
            HStack {
                if !isSearching {
                    Text(category.label)
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
            .onChange(of: mpd.queue.type) {
                isSearching = false
                query = ""
            }
        }
    }

    struct ArtistView: View {
        @Environment(MPD.self) private var mpd

        private let artist: Artist

        init(for artist: Artist, path: Binding<NavigationPath>) {
            self.artist = artist
            _path = path
        }

        @Binding var path: NavigationPath

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
                path.append(artist)
            })
        }
    }

    struct AlbumView: View {
        @Environment(MPD.self) private var mpd

        private let album: Album

        init(for album: Album, path: Binding<NavigationPath>) {
            self.album = album
            _path = path
        }

        @Binding var path: NavigationPath

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
                        if mpd.status.media?.id != album.id {
                            try? await ConnectionManager.command().play(album)
                        }
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

                guard let data = try? await ArtworkManager.shared.get(using: album.url) else {
                    return
                }

                artwork = NSImage(data: data)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: {
                path.append(album)
            })
            .contextMenu {
                Button("Add Album to Favorites") {
                    Task {
                        try? await ConnectionManager.command().addToFavorites(songs: ConnectionManager.command().getSongs(for: album))
                    }
                }

                if let playlists = (mpd.queue.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.queue.playlist }) : mpd.queue.playlists {
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

        @Binding var category: Category

        private let song: Song

        init(for song: Song, category: Binding<Category>) {
            self.song = song
            _category = category
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
                    if category.playlist != mpd.queue.playlist {
                        try? await ConnectionManager.command().loadPlaylist(category.playlist)
                    }

                    try? await ConnectionManager.command().play(song)
                }
            })
            .contextMenu {
                Button("Add Song to Favorites") {
                    Task {
                        try? await ConnectionManager.command().addToFavorites(songs: [song])
                    }
                }

                if let playlists = (mpd.queue.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.queue.playlist }) : mpd.queue.playlists {
                    Menu("Add Song to Playlist") {
                        ForEach(playlists) { playlist in
                            Button(playlist.name) {
                                Task {
                                    try? await ConnectionManager.command().addToPlaylist(playlist, songs: [song])
                                }
                            }
                        }
                    }

                    if let playlist = mpd.queue.playlist {
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
