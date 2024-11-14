//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct AppView: View {
    @Environment(Player.self) private var player

    struct Category: Identifiable, Hashable {
        let id = UUID()

        let type: MediaType
        let image: String
    }

    private let categories: [Category] = [
        .init(type: MediaType.album, image: "square.stack"),
        .init(type: MediaType.artist, image: "music.microphone"),
        .init(type: MediaType.song, image: "music.note"),
    ]

    @State private var selected: MediaType = .album

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                Section("Library") {
                    ForEach(categories) { category in
                        Label(category.type.rawValue, systemImage: category.image)
                            .tag(category.type)
                    }
                }

                Section("Playlists") {}
            }
            .navigationSplitViewColumnWidth(180)
        } content: {
            NavigationStack {
                switch selected {
                case .artist: ArtistsView()
                case .song: SongsView()
                default: AlbumsView()
                }
            }
            .navigationSplitViewColumnWidth(310)
        } detail: {
            ViewThatFits {
                CurrentView()
                    .onAppear {
                        player.status.trackElapsed = true
                    }
                    .onDisappear {
                        player.status.trackElapsed = false
                    }
            }
            .padding(60)
        }
        .background(.background)
    }

    struct HeaderView: View {
        @Environment(Player.self) private var player

        var title: String
        var type: MediaType
        
        @State private var hover: Bool = false
        @State private var showSearch: Bool = false
        @State private var query: String = ""
        
        @FocusState private var focused: Bool

        var body: some View {
            ZStack {
                HStack {
                    Text(title)
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
                            showSearch = true
                            focused = true
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
                                focused = false
                                showSearch = false
                            })
                    }
                    .background(.background)
                }
            }
            .padding(.horizontal, 15)
            .offset(y: -15)
        }
    }
    
    struct AlbumsView: View {
        @Environment(Player.self) private var player
        
        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    HeaderView(title: "Albums", type: .album)

                    LazyVStack(alignment: .leading, spacing: 15) {
                        ForEach(player.queue.search as? [Album] ?? player.queue.albums) { album in
                            HStack(spacing: 15) {
                                ZStack {
                                    ArtworkView(image: player.getArtwork(for: album.id)?.image)
                                        .cornerRadius(5)
                                        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                                }
                                .frame(width: 60)

                                VStack(alignment: .leading) {
                                    Text(album.title ?? "Unknown album")
                                        .font(.headline)
                                        .foregroundColor(Color(player.current != nil && player.current!.id.deletingLastPathComponent().path == album.id.deletingLastPathComponent().path ? .accent : .textColor))
                                        .lineLimit(2)
                                    Text(album.artist ?? "Unknown artist")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .id(album.id.deletingLastPathComponent())
                            .onAppear {
                                Task(priority: .userInitiated) {
                                    await player.setArtwork(for: album.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                }
                .onAppear {
                    Task(priority: .high) {
                        await player.queue.set(using: .album)
                    }

                    scrollToCurrent(proxy, animate: false)
                }
            }
        }

        private func scrollToCurrent(_ proxy: ScrollViewProxy, animate: Bool = true) {
            guard let id = player.current?.id else {
                return
            }

            if animate {
                withAnimation {
                    proxy.scrollTo(id.deletingLastPathComponent(), anchor: .center)
                }
            } else {
                proxy.scrollTo(id.deletingLastPathComponent(), anchor: .center)
            }
        }
    }

    
    struct ArtistsView: View {
        @Environment(Player.self) private var player

        var body: some View {
            ScrollView {
                HeaderView(title: "Artists", type: .artist)

                LazyVStack(alignment: .leading, spacing: 15) {
                    ForEach(player.queue.artists) { artist in
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
                .padding(.horizontal, 15)
            }
            .onAppear {
                Task(priority: .userInitiated) {
                    await player.queue.set(using: .artist)
                }
            }
        }
    }

    struct SongsView: View {
        @Environment(Player.self) private var player

        var body: some View {
            ScrollView {
                HeaderView(title: "Songs", type: .song)

                LazyVStack(alignment: .leading, spacing: 15) {
                    ForEach(player.queue.artists) { artist in
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
                .padding(.horizontal, 15)
            }
            .onAppear {
                Task(priority: .userInitiated) {
                    await player.queue.set(using: .artist)
                }
            }
        }
    }

    struct CurrentView: View {
        @Environment(Player.self) private var player
        @Environment(\.colorScheme) private var colorScheme

        @State private var artwork: Artwork?
        @State private var previousArtwork: Artwork?

        @State private var isBackgroundArtworkTransitioning = false
        @State private var isArtworkTransitioning = false

        var body: some View {
            VStack {
                ZStack {
                    ZStack {
                        ArtworkView(image: artwork?.image)

                        Rectangle()
                            .opacity(0)
                            .background(.ultraThinMaterial)
                    }
                    .scaledToFit()
                    .mask(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .clear]),
                            center: .center,
                            startRadius: -25,
                            endRadius: 225
                        )
                    )
                    .offset(y: 20)
                    .saturation(1.5)
                    .blur(radius: 20)
                    .opacity(0.6)
                    
                    ZStack {
                        ArtworkView(image: artwork?.image)

                        Rectangle()
                            .opacity(0)
                            .background(.ultraThinMaterial)
                    }
                    .scaledToFit()
                    .mask(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .clear]),
                            center: .center,
                            startRadius: -25,
                            endRadius: 225
                        )
                    )
                    .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: 0))
                    .offset(y: 105)
                    .blur(radius: 5)

                    ArtworkView(image: artwork?.image)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.2), radius: 16)
                        .frame(width: 250)
                }
                .offset(y: -25)
                .zIndex(100)

                Spacer()

                FooterView()
                    .frame(height: 80)
            }
            .onChange(of: player.current) {
                guard let current = player.current else {
                    return
                }

                Task(priority: .userInitiated) {
                    await player.setArtwork(for: current.id)
                    artwork = player.getArtwork(for: current.id)
                }
            }
            .onChange(of: artwork) { previous, _ in
                previousArtwork = previous

                isBackgroundArtworkTransitioning = true
                withAnimation(.easeInOut(duration: 0.5)) {
                    isBackgroundArtworkTransitioning = false
                }
                isArtworkTransitioning = true
                withAnimation(.easeInOut(duration: 0.1)) {
                    isArtworkTransitioning = false
                }
            }
        }
    }

    struct FooterView: View {
        @Environment(Player.self) private var player

        var body: some View {
            VStack(alignment: .leading, spacing: 7) {
                Text(player.current?.title ?? "No track selected")
                    .font(.system(size: 18))
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                ProgressView()
            }

            VStack {
                HStack(alignment: .center, spacing: 40) {
                    RepeatView()

                    HStack(spacing: 20) {
                        PreviousView()
                        PauseView()
                        NextView()
                    }

                    RandomView()
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
                    .fill(Color(.accent).opacity(0.1))
                    .aspectRatio(contentMode: .fit)
                    .scaledToFill()
            }
        }
    }

    struct PauseView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)

                Image(systemName: ((player.status.isPlaying ?? false) ? "pause" : "play") + ".fill")
                    .font(.system(size: 30))
            }
            .scaleEffect(hover ? 1.2 : 1)
            .animation(.interactiveSpring, value: hover)
            .onHover(perform: { value in
                hover = value
            })
            .onTapGesture(perform: {
                Task(priority: .userInitiated) {
                    await player.pause(player.status.isPlaying ?? false)
                }
            })
        }
    }

    struct PreviousView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: "backward.fill")
                .font(.system(size: 18))
                .padding(12)
                .scaleEffect(hover ? 1.2 : 1)
                .animation(.interactiveSpring, value: hover)
                .onHover(perform: { value in
                    hover = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        await player.previous()
                    }
                })
        }
    }

    struct NextView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: "forward.fill")
                .font(.system(size: 18))
                .padding(12)
                .scaleEffect(hover ? 1.2 : 1)
                .animation(.interactiveSpring, value: hover)
                .onHover(perform: { value in
                    hover = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        await player.next()
                    }
                })
        }
    }

    struct RandomView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            ZStack {
                Image(systemName: "shuffle")
                    .padding(10)
                    .scaleEffect(hover ? 1.2 : 1)
                    .animation(.interactiveSpring, value: hover)
                    .onHover(perform: { value in
                        hover = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            await player.setRandom(!(player.status.isRandom ?? false))
                        }
                    })
                
                if player.status.isRandom ?? false {
                    Circle()
                        .fill(Color(.accent))
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 12)
                }
            }
        }
    }

    struct RepeatView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            ZStack {
                Image(systemName: "repeat")
                    .padding(10)
                    .scaleEffect(hover ? 1.2 : 1)
                    .animation(.interactiveSpring, value: hover)
                    .onHover(perform: { value in
                        hover = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            await player.setRepeat(!(player.status.isRepeat ?? false))
                        }
                    })
                
                if player.status.isRepeat ?? false {
                    Circle()
                        .fill(Color(.accent))
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 12)
                }
            }
        }
    }

    struct ProgressView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.secondarySystemFill))
                            .frame(width: geometry.size.width, height: 3)

                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.accent))
                                .frame(
                                    width: max(0, (player.status.elapsed ?? 0) / (player.current?.duration ?? 100) * geometry.size.width),
                                    height: 3
                                )

                            Circle()
                                .fill(Color(.accent))
                                .frame(width: 8, height: 8)
                                .offset(x: 4)
                                .scaleEffect(hover ? 1.5 : 1)
                                .animation(.spring, value: hover)
                        }
                        .animation(.spring, value: player.status.elapsed)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        Task(priority: .userInitiated) {
                            await player.seek((value.location.x / geometry.size.width) * (player.current?.duration ?? 100))
                        }
                    })
                    .onHover(perform: { value in
                        hover = value
                    })

                    HStack(alignment: .center) {
                        Text(player.status.elapsed?.timeString ?? "-:--")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(player.current?.duration?.timeString ?? "-:--")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
