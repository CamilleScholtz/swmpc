//
//  IntelligenceView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SwiftUI

// MARK: - Layout Constants

private extension Layout.Size {
    static let intelligenceViewWidth: CGFloat = 300
}

private extension Layout.Padding {
    static let intelligenceView: CGFloat = 20
    static let intelligenceButton: CGFloat = 12
    static let intelligenceSmall: CGFloat = 8
}

struct IntelligenceView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    let target: IntelligenceTarget

    @Binding var showSheet: Bool

    private let loadingSentences: [LocalizedStringResource] = [
        "Analyzing music preferences…",
        "Matching tracks to vibe…",
        "Curating playlist…",
        "Curating queue…",
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

    init(target: IntelligenceTarget, showSheet: Binding<Bool>) {
        self.target = target
        _showSheet = showSheet

        _loadingSentence = State(initialValue: loadingSentences.randomElement()!)
        _suggestion = State(initialValue: suggestions.randomElement()!)
    }

    @State private var prompt = ""
    @State private var isLoading = false

    @State private var loadingSentence: LocalizedStringResource
    @State private var suggestion: LocalizedStringResource

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Layout.Spacing.large) {
            if isLoading {
                IntelligenceSparklesView()
                    .font(.system(size: 40))

                Text(loadingSentence)
                    .padding(.vertical, 5)
                    .font(.subheadline)
                    .onReceive(
                        Timer.publish(every: 1, on: .main, in: .common).autoconnect(),
                    ) { _ in
                        loadingSentence = loadingSentences.randomElement()!
                    }
            } else {
                Text("I want to listen to…")
                    .font(.headline)

                // NOTE: So this is super hacky, but we create this invisible
                // TextField that draws the focus, because `.focused` for
                // some reason does not work.
                TextField("", text: .constant(""))
                    .textFieldStyle(.plain)
                    .frame(width: 0, height: 0)

                TextField(String(localized: suggestion), text: $prompt)
                    .textFieldStyle(.plain)
                    .padding(Layout.Padding.intelligenceSmall)
                    .background(colorScheme == .dark ? .accent.opacity(0.2) : .accent)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.rounded))
                    .multilineTextAlignment(.center)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .offset(y: -15)
                    .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
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
                        if case let .playlist(playlist) = target {
                            playlist.wrappedValue = nil
                        }
                        showSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    .help("Cancel and close")

                    AsyncButton(actionButtonTitle) {
                        isLoading = true

                        try? await IntelligenceManager.shared.fill(target: target, prompt: prompt)
                        if case let .playlist(playlist) = target {
                            playlist.wrappedValue = nil
                        }

                        isLoading = false
                        showSheet = false
                    }
                    .asyncButtonStyle(.pulse)
                    .keyboardShortcut(.defaultAction)
                }
                .offset(y: -15)
            }
        }
        .frame(width: Layout.Size.intelligenceViewWidth)
        .padding(Layout.Padding.intelligenceView)
    }

    private var actionButtonTitle: String {
        switch target {
        case .playlist:
            "Create"
        case .queue:
            "Fill Queue"
        }
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
                    endPoint: UnitPoint(x: CGFloat(colors.count) + offset, y: 0),
                )
                .onAppear {
                    withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                        offset = -CGFloat(colors.count - 1)
                    }
                },
            )
            .mask(Image(systemSymbol: .sparkles))
    }
}
