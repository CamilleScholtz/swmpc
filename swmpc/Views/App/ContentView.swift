//
//  ContentView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import Combine
import SwiftUI

struct ContentView: View {
    @Environment(Player.self) private var player
    @Environment(\.dismiss) private var dismiss

    private var type: MediaType = .album

    init(for type: MediaType) {
        self.type = type
    }

    @State private var path = NavigationPath()
    @State private var showSearch: Bool = false
    @State private var hover = false
    
    @State private var search: String = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    HeaderView(for: type, showSearch: $showSearch)
                        .id("top")

                    LazyVStack(alignment: .leading, spacing: 15) {
                        switch type {
                        case .artist:
                            ArtistsView(path: $path)
                        case .song:
                            SongsView()
                        default:
                            AlbumsView(path: $path)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                }
                .ignoresSafeArea(.all, edges: .top)
                .task(id: type) {
                    // TODO: This is called twice on initialization.
                    await player.queue.set(for: type)
                    // TODO: Sometimes doesn't work?
                    scrollToCurrent(proxy, using: type, animate: false)
                }
                .onAppear {
                    NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "f" {
                            scrollToTop(proxy)
                            showSearch = true
                            return nil
                        }

//                        if event.charactersIgnoringModifiers?.lowercased() == "c" {
//                            scrollToCurrent(proxy, using: type)
//                            return nil
//                        }

                        return event
                    }
                }
            }
            .navigationDestination(for: URL.self) { uri in
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Image(systemName: "chevron.backward")
                            .padding(10)
                            .padding(.top, 25)
                            .scaleEffect(hover ? 1.2 : 1)
                            .animation(.interactiveSpring, value: hover)
                            .onHover(perform: { value in
                                hover = value
                            })
                            .onTapGesture {
                                dismiss()
                            }

                        switch type {
                        case .artist:
                            ArtistAlbumsView(for: uri, path: $path)
                        default:
                            AlbumSongsView(for: player.queue.media.first { $0.uri == uri }! as! Album)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                }
                .ignoresSafeArea(.all, edges: .top)
            }
        }
    }

    struct ArtistsView: View {
        @Environment(Player.self) private var player

        @Binding var path: NavigationPath

        private var artists: [Artist] {
            player.queue.search as? [Artist] ?? player.queue.media as? [Artist] ?? []
        }

        var body: some View {
            ForEach(artists) { artist in
                ArtistView(for: artist, path: $path)
            }
        }
    }

    struct ArtistAlbumsView: View {
        @Environment(Player.self) private var player

        private var uri: URL?
        private var artist: Artist? {
            player.queue.media.first { $0.uri == uri } as? Artist
        }

        init(for uri: URL? = nil, path: Binding<NavigationPath>) {
            self.uri = uri
            _path = path
        }

        @Binding var path: NavigationPath

        var body: some View {
            if let artist {
                VStack(spacing: 15) {
                    ForEach(artist.albums) { album in
                        AlbumView(for: album, path: $path)
                    }
                }
            }
        }
    }

    struct AlbumsView: View {
        @Environment(Player.self) private var player

        @Binding var path: NavigationPath

        private var albums: [Album] {
            player.queue.search as? [Album] ?? player.queue.media as? [Album] ?? []
        }

        var body: some View {
            ForEach(albums) { album in
                AlbumView(for: album, path: $path)
            }
        }
    }

    struct AlbumSongsView: View {
        @Environment(Player.self) private var player

        init(for album: Album) {
            self.album = album
        }

        @State var album: Album

        var body: some View {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 15) {
                    if let artwork = player.getArtwork(for: album)?.image {
                        ZStack {
                            ArtworkView(image: artwork)
                                .frame(width: 80)
                                .blur(radius: 17)
                                .offset(y: 7)

                            ArtworkView(image: artwork)
                                .cornerRadius(5)
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                                .frame(width: 100)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(album.title ?? "Unknown album")
                            .font(.system(size: 18))
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)

                        Text(album.artist ?? "Unknown artist")
                            .font(.system(size: 12))
                            .fontWeight(.semibold)

                        Text((album.songs.count > 1 ? "\(String(album.songs.count)) songs" : "1 song")
                            + " • "
                            // + (album.date ?? "s---")
                            // + " • "
                            + (album.duration?.timeString ?? "-:--"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 15)

                ForEach(album.songs) { song in
                    SongView(for: song)
                }
            }
            .task {
                await album.add(songs: try! player.commandManager.getSongs(for: album))
            }
        }
    }

    struct SongsView: View {
        @Environment(Player.self) private var player

        private var songs: [Song] {
            player.queue.search as? [Song] ?? player.queue.media as? [Song] ?? []
        }

        var body: some View {
            ForEach(songs) { song in
                SongView(for: song)
            }
        }
    }

    // TODO: The frame and offset is kinda hacky.
    struct HeaderView: View {
        @Environment(Player.self) private var player

        private var type: MediaType

        init(for type: MediaType, showSearch: Binding<Bool>) {
            self.type = type
            _showSearch = showSearch
        }

        @Binding var showSearch: Bool

        @State private var hover: Bool = false
        @State private var query: String = ""

        @FocusState private var focused: Bool

        var body: some View {
            HStack {
                if !showSearch {
                    Text(type.rawValue)
                        .font(.headline)

                    Spacer()

                    Image(systemName: "magnifyingglass")
                        .padding(10)
                        .scaleEffect(hover ? 1.2 : 1)
                        .animation(.interactiveSpring, value: hover)
                        .onHover(perform: { value in
                            hover = value
                        })
                        .onTapGesture(perform: {
                            startSearch()
                        })
                } else {
                    TextField("Search...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                        .focused($focused)
                        .onSubmit {
                            guard !query.isEmpty else {
                                player.queue.search = nil
                                return
                            }

                            Task(priority: .userInitiated) {
                                await player.queue.search(for: query, using: type)
                            }
                        }
                        .onDisappear {
                            player.queue.search = nil
                        }

                    Image(systemName: "xmark.circle")
                        .padding(10)
                        .scaleEffect(hover ? 1.2 : 1)
                        .animation(.interactiveSpring, value: hover)
                        .onHover(perform: { value in
                            hover = value
                        })
                        .onTapGesture(perform: {
                            stopSearch()
                        })
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 5)
            .padding(.horizontal, 15)
            .onChange(of: type) {
                stopSearch()
            }
        }

        private func startSearch() {
            query = ""
            focused = true
            showSearch = true
        }

        private func stopSearch() {
            query = ""
            focused = false
            showSearch = false
        }
    }

    struct ArtistView: View {
        @Environment(Player.self) private var player

        private let artist: Artist

        init(for artist: Artist, path: Binding<NavigationPath>) {
            self.artist = artist
            _path = path
        }

        @Binding var path: NavigationPath

        var body: some View {
            let uri = artist.uri.deletingLastPathComponent().deletingLastPathComponent()

            HStack(spacing: 15) {
                VStack(alignment: .leading) {
                    Text(artist.name)
                        .font(.headline)
                        .foregroundColor(player.current?.uri.deletingLastPathComponent().deletingLastPathComponent() == uri ? .accentColor : .primary)
                        .lineLimit(2)
                    Text(artist.albums.count == 1 ? "1 album" : "\(artist.albums.count) albums")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(uri)
            .contentShape(Rectangle())
            .onTapGesture {
                path.append(artist.uri)
            }
        }
    }

    struct AlbumView: View {
        @Environment(Player.self) private var player

        private let album: Album

        init(for album: Album, path: Binding<NavigationPath>) {
            self.album = album
            _path = path
        }

        @Binding var path: NavigationPath

        var body: some View {
            let uri = album.uri.deletingLastPathComponent()

            HStack(spacing: 15) {
                ArtworkView(image: player.getArtwork(for: album)?.image)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                    .frame(width: 60)

                VStack(alignment: .leading) {
                    Text(album.title ?? "Unknown album")
                        .font(.headline)
                        .foregroundColor(player.current?.uri.deletingLastPathComponent() == uri ? .accentColor : .primary)
                        .lineLimit(2)
                    Text(album.artist ?? "Unknown artist")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(uri)
            .task(id: uri) {
                // TODO: This can probably be made even a little snappier.
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else {
                    return
                }

                await player.setArtwork(for: album)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                path.append(album.uri)
            }
        }
    }

    struct SongView: View {
        @Environment(Player.self) private var player

        private let song: Song
        private var animation: Animation {
            .linear(duration: 0.5).repeatForever()
        }

        init(for song: Song) {
            self.song = song
        }

        @State private var animating = true
        @State private var hover: Bool = false

        var body: some View {
            let uri = song.uri

            HStack(spacing: 15) {
                Group {
                    if !hover, player.current?.uri != uri {
                        Text(song.track ?? "-")
                            .font(.title3)
                            .fontWeight(.regular)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    } else {
                        let isPlaying = player.status.isPlaying ?? false

                        if player.current?.uri == uri {
                            HStack(spacing: 1.5) {
                                bar(low: 0.4)
                                    .animation(isPlaying ? animation.speed(1.5) : .default, value: animating)
                                bar(low: 0.3)
                                    .animation(isPlaying ? animation.speed(1.2) : .default, value: animating)
                                bar(low: 0.5)
                                    .animation(isPlaying ? animation.speed(1.0) : .default, value: animating)
                                bar(low: 0.3)
                                    .animation(isPlaying ? animation.speed(1.7) : .default, value: animating)
                                bar(low: 0.5)
                                    .animation(isPlaying ? animation.speed(1.0) : .default, value: animating)
                            }
                            .onAppear {
                                animating = isPlaying
                            }
                            .onChange(of: isPlaying) { _, _ in
                                animating = isPlaying
                            }
                        } else {
                            Image(systemName: "play.fill")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .frame(width: 20)

                VStack(alignment: .leading) {
                    Text(song.title ?? "Unknown album")
                        .font(.headline)
                        .foregroundColor(player.current?.uri == uri ? .accentColor : .primary)
                        .lineLimit(2)
                    Text((song.artist ?? "Unknown artist") + " • " + (song.duration?.timeString ?? "-:--"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(uri)
            .contentShape(Rectangle())
            .onHover(perform: { value in
                hover = value
            })
            .onTapGesture {
                Task(priority: .userInitiated) {
                    await player.play(song)
                }
            }
        }

        private func bar(low: CGFloat = 0.0, high: CGFloat = 1.0) -> some View {
            RoundedRectangle(cornerRadius: 2)
                .fill(player.status.isPlaying ?? false ? .accent : .secondary)
                .animation(.spring, value: player.status.isPlaying ?? false)
                .frame(height: (animating ? high : low) * 12)
                .frame(width: 2)
        }
    }

    struct ArtworkView: View {
        let image: NSImage?

        @State private var loaded = false

        var body: some View {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .opacity(loaded ? 1 : 0)
                    .background(Color(.accent).opacity(0.1))
                    .animation(.spring, value: loaded)
                    .onAppear {
                        loaded = true
                    }
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill).opacity(0.3))
                    .aspectRatio(contentMode: .fit)
                    .scaledToFill()
            }
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, using type: MediaType, animate: Bool = true) {
        guard var uri = player.current?.uri else {
            return
        }

        switch type {
        case .artist:
            uri = uri.deletingLastPathComponent().deletingLastPathComponent()
        default:
            uri = uri.deletingLastPathComponent()
        }

        if animate {
            withAnimation {
                proxy.scrollTo(uri, anchor: .center)
            }
        } else {
            proxy.scrollTo(uri, anchor: .center)
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
