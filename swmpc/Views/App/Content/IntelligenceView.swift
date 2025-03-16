//
//  IntelligenceView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

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
