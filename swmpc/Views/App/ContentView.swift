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

    @Binding var type: MediaType
    @Binding var path: NavigationPath

    init(for type: Binding<MediaType>, path: Binding<NavigationPath>) {
        _type = type
        _path = path
    }

    @State private var showSearch: Bool = false
    @State private var hover = false

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
                    .offset(y: -7.5)
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                }
                .ignoresSafeArea(.all)
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
            .navigationDestination(for: Artist.self) { artist in
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        backButton()
                        ArtistAlbumsView(for: artist, path: $path)
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                }
                .ignoresSafeArea(.all)
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
                .ignoresSafeArea(.all)
            }
        }
    }

    private func backButton() -> some View {
        Image(systemName: "chevron.backward")
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(hover ? Color(.secondarySystemFill): .clear)
            )
            .padding(.top, 12)
            .animation(.interactiveSpring, value: hover)
            .onHover(perform: { value in
                hover = value
            })
            .onTapGesture {
                dismiss()
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

        private var artist: Artist

        init(for artist: Artist, path: Binding<NavigationPath>) {
            self.artist = artist
            _path = path
        }

        @Binding var path: NavigationPath

        var body: some View {
            VStack(spacing: 15) {
                ForEach(artist.albums) { album in
                    AlbumView(for: album, path: $path)
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
            _album = State(initialValue: album)
        }

        @State private var album: Album
        @State private var hover = false

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

                            if player.current?.albumUri == album.uri {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 66, height: 66)
                                    .shadow(radius: 10)
                                    .overlay {
                                        Image(systemName: player.status.isPlaying ?? false ? "pause.fill" : "play.fill")
                                            .font(.system(size: 22))
                                    }
                            }
                        }
                        .onTapGesture {
                            Task(priority: .userInitiated) {
                                await player.pause(player.status.isPlaying ?? false)
                            }
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
                            + (album.duration?.humanTimeString ?? "0m"))
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
                await player.setArtwork(for: album)
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

        @State private var hover = false
        @State private var query = ""

        @FocusState private var focused: Bool

        var body: some View {
            HStack {
                if !showSearch {
                    Text(type.rawValue)
                        .font(.headline)

                    Spacer()

                    Image(systemName: "magnifyingglass")
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(hover ? Color(.secondarySystemFill): .clear)
                        )
                        .animation(.interactiveSpring, value: hover)
                        .onHover(perform: { value in
                            hover = value
                        })
                        .onTapGesture(perform: {
                            showSearch = true
                        })
                } else {
                    TextField("Search", text: $query)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.secondarySystemFill))
                        .cornerRadius(4)
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
                        .onAppear {
                            query = ""
                            focused = true
                        }
                        .onDisappear {
                            query = ""
                            focused = false
                        }

                    Image(systemName: "xmark.circle")
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(hover ? Color(.secondarySystemFill): .clear)
                        )
                        .animation(.interactiveSpring, value: hover)
                        .onHover(perform: { value in
                            hover = value
                        })
                        .onTapGesture(perform: {
                            showSearch = false
                        })
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 15)
            .onChange(of: type) {
                showSearch = false
            }
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
            HStack(spacing: 15) {
                VStack(alignment: .leading) {
                    Text(artist.name)
                        .font(.headline)
                        .foregroundColor(player.current?.artistUri == artist.uri ? .accentColor : .primary)
                        .lineLimit(2)
                    Text(artist.albums.count == 1 ? "1 album" : "\(artist.albums.count) albums")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(artist.uri)
            .contentShape(Rectangle())
            .onTapGesture {
                path.append(artist)
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
            HStack(spacing: 15) {
                ArtworkView(image: player.getArtwork(for: album)?.image)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                    .frame(width: 60)

                VStack(alignment: .leading) {
                    Text(album.title ?? "Unknown album")
                        .font(.headline)
                        .foregroundColor(player.current?.albumUri == album.uri ? .accentColor : .primary)
                        .lineLimit(2)
                    Text(album.artist ?? "Unknown artist")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(album.uri)
            .task(id: album.uri) {
                // TODO: This can probably be made even a little snappier.
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else {
                    return
                }

                await player.setArtwork(for: album)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                path.append(album)
            }
        }
    }

    struct SongView: View {
        @Environment(Player.self) private var player

        private let song: Song

        init(for song: Song) {
            self.song = song
        }

        @State private var animating = false
        @State private var hover: Bool = false

        var body: some View {
            HStack(spacing: 15) {
                Group {
                    if !hover, player.current?.uri != song.uri {
                        Text(song.track ?? "-")
                            .font(.title3)
                            .fontWeight(.regular)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    } else {
                        if player.current?.uri == song.uri {
                            WaveView()
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
                        .foregroundColor(player.current?.uri == song.uri ? .accentColor : .primary)
                        .lineLimit(2)
                    Text((song.artist ?? "Unknown artist") + " • " + (song.duration?.timeString ?? "-:--"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(song.uri)
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

    struct WaveView: View {
        @Environment(Player.self) private var player

        @State private var animating = false

        var body: some View {
            let isPlaying = player.status.isPlaying ?? false

            HStack(spacing: 1.5) {
                bar(low: 0.4)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.5).repeatForever() : .linear(duration: 0.5), value: animating)
                bar(low: 0.3)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.2).repeatForever() : .linear(duration: 0.5), value: animating)
                bar(low: 0.5)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.0).repeatForever() : .linear(duration: 0.5), value: animating)
                bar(low: 0.3)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.7).repeatForever() : .linear(duration: 0.5), value: animating)
                bar(low: 0.5)
                    .animation(isPlaying ? .linear(duration: 0.5).speed(1.0).repeatForever() : .linear(duration: 0.5), value: animating)
            }
            .onAppear {
                animating = isPlaying
            }
            .onDisappear {
                animating = false
            }
            .onChange(of: isPlaying) { _, value in
                animating = value
            }
        }

        private func bar(low: CGFloat = 0.0, high: CGFloat = 1.0) -> some View {
            RoundedRectangle(cornerRadius: 2)
                // .fill(colored ? (player.status.isPlaying ?? false ? .accent : .secondary) : .primary)
                .fill(.secondary)
                .animation(.spring, value: player.status.isPlaying ?? false)
                .frame(width: 2, height: (animating ? high : low) * 12)
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, using type: MediaType, animate: Bool = true) {
        guard let current = player.current else {
            return
        }

        var uri = current.uri
        switch type {
        case .artist:
            uri = current.artistUri
        default:
            uri = current.albumUri
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
