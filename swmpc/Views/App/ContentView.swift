//
//  ContentView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import SwiftUI

struct ContentView: View {
    @Environment(Player.self) private var player

    private var type: MediaType = .album

    init(for type: MediaType) {
        self.type = type
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    HeaderView(for: type)

                    LazyVStack(alignment: .leading, spacing: 15) {
                        switch type {
                        case .artist:
                            ArtistsView()
                        case .song:
                            SongsView()
                        default:
                            AlbumsView()
                        }
                    }
                    .padding(.horizontal, 15)
                }
                // TODO: This is called twice?
                // TODO: First change of type, scrollToCurrent doesn't work.
                .task(id: type) {
                    await player.queue.set(using: type)
                    scrollToCurrent(proxy, using: type, animate: false)
                }
            }
        }
    }

    struct AlbumsView: View {
        @Environment(Player.self) private var player

        private var albums: [Album] {
            player.queue.search as? [Album] ?? player.queue.albums
        }

        var body: some View {
            ForEach(albums) { album in
                let dir = album.id.deletingLastPathComponent()

                HStack(spacing: 15) {
                    ArtworkView(image: player.getArtwork(for: album.id)?.image)
                        .cornerRadius(5)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                        .frame(width: 60)

                    VStack(alignment: .leading) {
                        Text(album.title ?? "Unknown album")
                            .font(.headline)
                            .foregroundColor(player.current?.id.deletingLastPathComponent() == dir ? .accentColor : .primary)
                            .lineLimit(2)
                        Text(album.artist ?? "Unknown artist")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .id(dir)
                .task(id: dir) {
                    // TODO: This can probably be made even a little snappier.
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    guard !Task.isCancelled else {
                        return
                    }

                    await player.setArtwork(for: album.id)
                }
            }
        }
    }

    struct ArtistsView: View {
        @Environment(Player.self) private var player

        private var artists: [Artist] {
            player.queue.search as? [Artist] ?? player.queue.artists
        }

        var body: some View {
            ForEach(artists) { artist in
                let dir = artist.id.deletingLastPathComponent().deletingLastPathComponent()

                HStack(spacing: 15) {
                    VStack(alignment: .leading) {
                        Text(artist.name)
                            .font(.headline)
                            .foregroundColor(player.current?.id.deletingLastPathComponent().deletingLastPathComponent() == dir ? .accentColor : .primary)
                            .lineLimit(2)
                        Text(artist.albums.count == 1 ? "1 album" : "\(artist.albums.count) albums")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .id(dir)
            }
        }
    }

    struct SongsView: View {
        @Environment(Player.self) private var player

        private var artists: [Artist] {
            player.queue.search as? [Artist] ?? player.queue.artists
        }

        var body: some View {
            ForEach(artists) { artist in
                HStack(spacing: 15) {
                    VStack(alignment: .leading) {
                        Text(artist.name)
                            .font(.headline)
                            .lineLimit(2)
                        Text(artist.albums.count == 1 ? "1 album" : "\(artist.albums.count) albums")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    struct HeaderView: View {
        @Environment(Player.self) private var player

        private var type: MediaType

        init(for type: MediaType) {
            self.type = type
        }

        @State private var hover: Bool = false
        @State private var showSearch: Bool = false
        @State private var query: String = ""

        @FocusState private var focused: Bool

        var body: some View {
            ZStack {
                HStack {
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
                }

                if showSearch {
                    HStack {
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
                    .background(.background)
                }
            }
            .padding(.horizontal, 15)
            .offset(y: -15)
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
                    .fill(Color(.accent).opacity(0.1))
                    .aspectRatio(contentMode: .fit)
                    .scaledToFill()
            }
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, using type: MediaType, animate: Bool = true) {
        guard var id = player.current?.id else {
            return
        }

        switch type {
        case .artist:
            id = id.deletingLastPathComponent().deletingLastPathComponent()
        case .song:
            print("TODO")
        default:
            id = id.deletingLastPathComponent()
        }

        if animate {
            withAnimation {
                proxy.scrollTo(id, anchor: .center)
            }
        } else {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}
