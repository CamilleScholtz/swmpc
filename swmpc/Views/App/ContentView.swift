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
                        case .song, .playlist:
                            SongsView()
                        default:
                            AlbumsView(path: $path)
                        }
                    }
                    .id(type)
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

                    guard type != .song, let song = player.currentSong else {
                        return
                    }

                    player.currentMedia = await player.queue.get(type: type, using: song)
                }
                .task(id: player.currentSong) {
                    guard type != .song, let song = player.currentSong else {
                        return
                    }

                    player.currentMedia = await player.queue.get(type: type, using: song)
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
                        AlbumSongsView(for: album, path: $path)
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
                    .fill(hover ? Color(.secondarySystemFill) : .clear)
            )
            .padding(.top, 12)
            .animation(.interactiveSpring, value: hover)
            .onHover(perform: { value in
                hover = value
            })
            .onTapGesture {
                path.removeLast()
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
        @Environment(\.colorScheme) var colorScheme

        init(for album: Album,  path: Binding<NavigationPath>) {
            _album = State(initialValue: album)
            _path = path
        }

        @Binding var path: NavigationPath
        
        @State private var album: Album
        @State private var hover = false

        var body: some View {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 15) {
                    if let artwork = player.getArtwork(for: album)?.image {
                        ZStack(alignment: .bottom) {
                            ArtworkView(image: artwork)
                                .frame(width: 80)
                                .blur(radius: 17)
                                .offset(y: 7)
                                .saturation(1.5)
                                .blendMode(colorScheme == .dark ? .softLight : .normal)
                                .opacity(0.5)

                            ArtworkView(image: artwork)
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
                                            Image(systemName: "play.fill")
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
                                    .opacity(player.currentMedia?.id == album.id ? 1 : 0)
                                    .animation(.interactiveSpring, value: player.currentMedia?.id == album.id)
                                )
                        }
                        .onHover(perform: { value in
                            hover = value
                        })
                        .onTapGesture {
                            Task(priority: .userInitiated) {
                                if player.currentMedia?.id != album.id {
                                    await player.play(album)
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
                            .onTapGesture {
                                Task(priority: .userInitiated) {
                                    guard let media = await player.queue.get(type: .artist, using: album) else {
                                        return
                                    }
                                    
                                    path.append(media)
                                }
                            }

                        Text((album.tracks ?? 0 > 1 ? "\(String(album.tracks!)) songs" : "1 song")
                            + " • "
                            + (album.duration?.humanTimeString ?? "0m"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 15)

                if let songs = album.songs {
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
                await album.set(songs: try! player.commandManager.getSongs(for: album))
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
                                .fill(hover ? Color(.secondarySystemFill) : .clear)
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
                                await player.queue.setSearch(for: query, using: type)
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
                                .fill(hover ? Color(.secondarySystemFill) : .clear)
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
                        .foregroundColor(player.currentMedia?.id == artist.id ? .accentColor : .primary)
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
                    Text(album.title)
                        .font(.headline)
                        .foregroundColor(player.currentMedia?.id == album.id ? .accentColor : .primary)
                        .lineLimit(2)
                    Text(album.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .id(album)
            .task(id: album) {
                // TODO: This can probably be made even a little snappier.
                try? await Task.sleep(nanoseconds: 25_000_000)
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
                    if !hover, player.currentSong != song {
                        Text(String(song.track))
                            .font(.title3)
                            .fontWeight(.regular)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    } else {
                        if player.currentSong == song {
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
                    Text(song.title)
                        .font(.headline)
                        .foregroundColor(player.currentSong == song ? .accentColor : .primary)
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
                    .background(Color(.secondarySystemFill).opacity(0.3))
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
                .fill(.secondary)
                .frame(width: 2, height: (animating ? high : low) * 12)
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, using _: MediaType, animate: Bool = true) {
        guard let song = player.currentSong else {
            return
        }

        if animate {
            withAnimation {
                proxy.scrollTo(song, anchor: .center)
            }
        } else {
            proxy.scrollTo(song, anchor: .center)
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
