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

    init(target: IntelligenceTarget, showSheet: Binding<Bool>) {
        self.target = target
        _showSheet = showSheet

        _loadingSentence = State(initialValue: loadingSentences.randomElement() ?? "…")
    }

    @State private var prompt = ""
    @State private var isLoading = false

    @State private var loadingSentence: LocalizedStringResource
    @State private var colorOffset: CGFloat = 0

    @FocusState private var isFocused: Bool

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
        "Tuning into your frequency…",
        "Measuring vibe consistency…",
        "Harmonizing track flow…",
        "Blending genres…",
        "Ranking tracks by mood match…",
        "Rebalancing sonic palette…",
        "Extracting emotional tone…",
        "Testing replay value…",
        "Simulating crowd reaction…",
        "Syncing tempo with heartbeat…",
        "Balancing energy curves…",
        "Measuring danceability index…",
        "Estimating sing-along potential…",
        "Locking in auditory aesthetic…",
        "Rolling dice for track order…",
        "Consulting the hipster council…",
        "Scraping forgotten MySpace pages…",
        "Peeking at DJ forums circa 2007…",
        "Training a tiny AI just for this playlist…",
        "Peeking at your guilty pleasures…",
        "Overthinking song transitions…",
        "Polling imaginary audience…",
        "Summoning obscure SoundCloud producers…",
        "Fact-checking vibes on Wikipedia…",
        "Crowdsourcing from ghosts of Limewire…",
        "Consulting your future self’s nostalgia…",
        "Googling 'songs like Despacito'…",
    ]

    private let colors: [Color] = [
        .blue, .purple, .red, .orange, .yellow, .cyan, .blue, .purple,
    ]

    private var actionButtonTitle: LocalizedStringResource {
        switch target {
        case .playlist:
            "Fill Playlist"
        case .queue:
            "Fill Queue"
        }
    }

    var body: some View {
        VStack(spacing: Layout.Spacing.large) {
            if isLoading {
                Spacer()
            }

            Image(systemSymbol: .sparkles)
                .font(.system(size: isLoading ? 42 : 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: colors.map { $0.opacity(0.8) },
                        startPoint: UnitPoint(x: colorOffset, y: 0),
                        endPoint: UnitPoint(
                            x: CGFloat(colors.count) + colorOffset,
                            y: 0,
                        ),
                    ),
                )
                .shadow(radius: isLoading ? 9 : 8, y: 1)

            if isLoading {
                Spacer()

                Text(loadingSentence)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .onReceive(
                        Timer.publish(every: 1.5, on: .main, in: .common).autoconnect(),
                    ) { _ in
                        withAnimation(.spring) {
                            loadingSentence = loadingSentences.randomElement() ?? "…"
                        }
                    }

                Spacer()
            } else {
                VStack(spacing: Layout.Spacing.small) {
                    Text("I want to listen to…")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                TextField("", text: $prompt)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(12)
                    .glassEffect(.regular.interactive())
                    .multilineTextAlignment(.center)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .onAppear {
                        isFocused = false
                    }

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

                    AsyncButton(String(localized: actionButtonTitle), role: .confirm) {
                        isLoading = true

                        try? await IntelligenceManager.shared.fill(target: target, prompt: prompt)
                        if case let .playlist(playlist) = target {
                            playlist.wrappedValue = nil
                        }

                        isLoading = false
                        showSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .asyncButtonStyle(.pulse)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, Layout.Padding.medium)
            }
        }
        .padding(Layout.Padding.large)
        #if os(iOS)
            .frame(maxHeight: .infinity)
            .presentationDetents([.medium])
            .ignoresSafeArea()
        #elseif os(macOS)
            .frame(width: Layout.Size.intelligenceViewWidth, height: Layout.Size.intelligenceViewWidth / 1.68)
        #endif
            .background {
                LinearGradient(
                    colors: colors.map { $0.opacity(colorScheme == .dark ? 0.6 : 0.8) },
                    startPoint: UnitPoint(x: colorOffset, y: 0),
                    endPoint: UnitPoint(
                        x: CGFloat(colors.count) + colorOffset,
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
            }
            .onAppear {
                withAnimation(
                    .linear(duration: 15)
                        .repeatForever(autoreverses: false),
                ) {
                    colorOffset = -CGFloat(colors.count - 1)
                }
            }
            .animation(.spring, value: isLoading)
    }
}
