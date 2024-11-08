//
//  ContentView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct ContentView: View {
    @Environment(Player.self) private var player

    var body: some View {
        NavigationSplitView {
            Navigation()
        } content: {
            Albums()
        } detail: {
            Current()
        }
    }

    struct Navigation: View {
        struct Category: Hashable, Identifiable {
            var id: Self { self }

            let image: String
            let name: String
            // let destination: AnyView?
        }

        private let categories = [
            Category(image: "music.note", name: "Albums"),
            Category(image: "music.note", name: "Artists"),
            Category(image: "music.note", name: "Songs"),
        ]
        @State private var selectedCategory: Category? = nil

        init() {
            selectedCategory = categories.first
        }

        var body: some View {
            TextField("Search", text: .constant(""))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(10)

            List(selection: $selectedCategory) {
                // NavigationLink(destination: Albums()) {
                Label("Albums", systemImage: "square.stack")
                Label("Artists", systemImage: "music.microphone")
                Label("Songs", systemImage: "music.note")
                // }
            }
        }
    }

    struct Pause: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: (player.status.isPlaying ?? false) ? "pause.fill" : "play.fill")
                .font(.system(size: 22))
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

    struct Previous: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: "backward.fill")
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

    struct Next: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: "forward.fill")
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

    struct Random: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: "shuffle")
                .foregroundColor(Color((player.status.isRandom ?? false) ? .accent : .textColor))
                .animation(.interactiveSpring, value: player.status.isRandom)
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
        }
    }

    struct Repeat: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: "repeat")
                .foregroundColor(Color((player.status.isRepeat ?? false) ? .accent : .textColor))
                .animation(.interactiveSpring, value: player.status.isRepeat)
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
        }
    }

    struct Progress: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.accent))
                        .frame(
                            width: (player.status.elapsed ?? 0) / (player.current?.duration ?? 100) * 250,
                            height: hover ? 8 : 4
                        )
                        .animation(.spring, value: player.status.elapsed)

                    Rectangle()
                        .fill(Color(.textBackgroundColor))
                        .frame(
                            width: Double.maximum(0, 250 - ((player.status.elapsed ?? 0) / (player.current?.duration ?? 100) * 250)),
                            height: hover ? 8 : 4
                        )
                        .animation(.spring, value: player.status.elapsed)
                }
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    Task(priority: .userInitiated) {
                        await player.seek((value.location.x / 250) * (player.current?.duration ?? 100))
                    }
                })

                HStack(alignment: .center) {
                    Text(player.status.elapsed?.timeString ?? "-:--")
                        .font(.system(size: 10))
                        .offset(x: 5, y: 3)

                    Spacer()

                    Text(player.current?.duration?.timeString ?? "-:--")
                        .font(.system(size: 10))
                        .offset(x: -5, y: 3)
                }
            }
            .animation(.interactiveSpring, value: hover)
            .onHover(perform: { value in
                hover = value
            })
        }
    }

    struct Albums: View {
        @Environment(Player.self) private var player

        var body: some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(player.queue.albums) { album in
                        HStack(spacing: 15) {
                            ZStack {
                                Artwork(image: album.artwork)
                                    .scaleEffect(0.97)
                                    .blur(radius: 7)
                                    .offset(y: 1)
                                    .blendMode(.multiply)
                                    .opacity(0.5)

                                Artwork(image: album.artwork)
                            }
                            .frame(width: 60)

                            VStack(alignment: .leading) {
                                Text(album.title ?? "Unknown album")
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(album.artist ?? "Unknown artist")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .onAppear {
                            guard album.artwork == nil else {
                                return
                            }

                            Task {
                                await player.queue.setArtwork(album.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    struct Current: View {
        @Environment(Player.self) private var player

        var body: some View {
            ZStack {
                //            Artwork(image: player.current?.album.artwork)
                //                .scaleEffect(0.97)
                //                .blur(radius: 7)
                //                .offset(y: 1)
                //                .blendMode(.multiply)
                //                .opacity(0.5)
                //
                //            Artwork(image: player.current.artwork)
            }
        }
    }

    struct Artwork: View {
        let image: NSImage?

        @State private var loaded = false

        var body: some View {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .cornerRadius(5)
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .opacity(loaded ? 1 : 0)
                    .animation(.spring, value: loaded)
                    .onAppear {
                        loaded = true
                    }
            } else {
                ZStack {
                    Rectangle()
                        .fill(.background.opacity(0.3))
                        .aspectRatio(contentMode: .fill)
                        .cornerRadius(5)
                        .scaledToFill()
                }
            }
        }
    }
}
