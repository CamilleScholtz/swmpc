//
//  IntelligenceView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SFSafeSymbols
import SwiftUI

private extension Layout.Size {
    static let intelligenceViewWidth: CGFloat = 350
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
    @State private var backgroundOffset: CGFloat = 0

    @FocusState private var isFocused: Bool

    private let backgroundColors: [Color] = [
        .blue, .purple, .red, .orange, .yellow, .cyan, .blue, .purple,
    ]

    var body: some View {
        VStack(spacing: Layout.Spacing.large) {
            if isLoading {
                VStack(spacing: Layout.Spacing.large) {
                    Image(systemSymbol: .sparkles)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: backgroundColors.map { $0.opacity(0.8) },
                                startPoint: UnitPoint(x: backgroundOffset, y: 0),
                                endPoint: UnitPoint(
                                    x: CGFloat(backgroundColors.count) + backgroundOffset,
                                    y: 0,
                                ),
                            ),
                        )
                        .padding(.top, Layout.Padding.large)

                    Text(loadingSentence)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .onReceive(
                            Timer.publish(every: 1.5, on: .main, in: .common).autoconnect(),
                        ) { _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                loadingSentence = loadingSentences.randomElement()!
                            }
                        }
                }
                .frame(maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                VStack(spacing: Layout.Spacing.medium) {
                    VStack(spacing: Layout.Spacing.small) {
                        Image(systemSymbol: .sparkles)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: backgroundColors.map { $0.opacity(0.8) },
                                    startPoint: UnitPoint(x: backgroundOffset, y: 0),
                                    endPoint: UnitPoint(
                                        x: CGFloat(backgroundColors.count) + backgroundOffset,
                                        y: 0,
                                    ),
                                ),
                            )
                            .padding(.top, Layout.Padding.small)

                        Text("I want to listen to…")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, Layout.Padding.medium)

                    TextField(String(localized: suggestion), text: $prompt)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(12)
                        .glassEffect(.regular.interactive())
                        .multilineTextAlignment(.center)
                        .disableAutocorrection(true)
                        .focused($isFocused)
                        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                            guard !isFocused else {
                                return
                            }

                            withAnimation(.easeInOut(duration: 0.3)) {
                                suggestion = suggestions.randomElement()!
                            }
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
                }

                Spacer()

                HStack(spacing: Layout.Spacing.medium) {
                    Button("Cancel", role: .cancel) {
                        if case let .playlist(playlist) = target {
                            playlist.wrappedValue = nil
                        }
                        showSheet = false
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .help("Cancel and close")

                    AsyncButton {
                        isLoading = true

                        try? await IntelligenceManager.shared.fill(target: target, prompt: prompt)
                        if case let .playlist(playlist) = target {
                            playlist.wrappedValue = nil
                        }

                        isLoading = false
                        showSheet = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemSymbol: .sparkles)
                                .font(.callout.weight(.semibold))
                            Text(actionButtonTitle)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .asyncButtonStyle(.pulse)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, Layout.Padding.medium)
            }
        }
        .frame(width: Layout.Size.intelligenceViewWidth)
        .padding(Layout.Padding.large)
        .background {
            LinearGradient(
                colors: backgroundColors.map { $0.opacity(colorScheme == .dark ? 0.6 : 0.9) },
                startPoint: UnitPoint(x: backgroundOffset, y: 0),
                endPoint: UnitPoint(
                    x: CGFloat(backgroundColors.count) + backgroundOffset,
                    y: 0,
                ),
            )
            .mask(
                RadialGradient(
                    colors: [
                        .black,
                        .clear,
                    ],
                    center: .init(x: 0.5, y: 0.1),
                    startRadius: 0,
                    endRadius: Layout.Size.intelligenceViewWidth / 2 + 30,
                )
                .blur(radius: 50),
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .linear(duration: 15)
                        .repeatForever(autoreverses: false),
                ) {
                    backgroundOffset = -CGFloat(backgroundColors.count - 1)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoading)
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
