//
//  IntelligenceView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct IntelligencePlaylistView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    @Binding var showIntelligencePlaylistSheet: Bool
    @Binding var playlistToEdit: Playlist?

    private let loadingSentences: [LocalizedStringResource] = [
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

    private let suggestions: [LocalizedStringResource] = [
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

    @State private var loadingSentence: LocalizedStringResource
    @State private var suggestion: LocalizedStringResource

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 15) {
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

                TextField(String(localized: suggestion), text: $prompt)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(colorScheme == .dark ? .accent.opacity(0.2) : .accent)
                    .cornerRadius(100)
                    .multilineTextAlignment(.center)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .offset(y: -15)
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

                Spacer()

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
                .offset(y: -15)
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

    @State private var isPressed = false

    var body: some View {
        VStack {
            HStack {
                IntelligenceSparklesView()
                Text(title)
            }
            .padding(12)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
            )
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(.interactiveSpring, value: isPressed)
            .opacity(isIntelligenceEnabled ? 1 : 0.7)
            .onTapGesture {
                guard isIntelligenceEnabled else {
                    return
                }

                withAnimation(.spring) {
                    isPressed = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPressed = false
                    }
                }
            }

            if !isIntelligenceEnabled {
                Text("Enable AI features in settings to use this feature.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .offset(y: 10)
            }
        }
    }
}
