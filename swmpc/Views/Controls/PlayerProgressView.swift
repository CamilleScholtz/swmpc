//
//  PlayerProgressView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import MPDKit
import SwiftUI
#if os(iOS)
    import SwiftUIIntrospect
#endif

struct PlayerProgressView: View {
    @Environment(MPD.self) private var mpd

    let showTimestamps: Bool

    @State private var sliderValue: Double = 0
    @State private var isEditing = false

    private var elapsed: Double {
        mpd.status.elapsed ?? 0
    }

    private var duration: Double {
        max(mpd.status.song?.duration ?? 100, 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            Slider(
                value: $sliderValue,
                in: 0 ... duration,
                onEditingChanged: { editing in
                    if editing {
                        isEditing = true
                    } else {
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command {
                                try await $0.seek(sliderValue)
                            }

                            try? await Task.sleep(for: .milliseconds(500))
                            isEditing = false
                        }
                    }
                },
            )
            .controlSize(.mini)
            #if os(iOS)
                // XXX: .mini control size is still too large on iOS 26.
                .introspect(.slider, on: .iOS(.v26)) { value in
                    value.sliderStyle = .thumbless
                }
            #endif
                .disabled(mpd.status.song == nil)
                .help("Seek to position in track")
                .onChange(of: elapsed) { previous, value in
                    guard !isEditing else {
                        return
                    }

                    let delta = value - previous
                    let isTick = delta > 0 && delta < 2

                    withAnimation(isTick ? .linear(duration: 1) : .snappy(duration: 0.25)) {
                        sliderValue = value
                    }
                }
                .onAppear {
                    sliderValue = elapsed
                }

            if showTimestamps {
                HStack(alignment: .center) {
                    TimestampText(time: mpd.status.elapsed)

                    Spacer()

                    TimestampText(time: mpd.status.song?.duration)
                }
            }
        }
    }
}

private struct TimestampText: View {
    let time: Double?

    var body: some View {
        Text(time?.timeString ?? "0:00")
            .monospacedDigit()
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Color.timestampLabel)
    }
}

private extension Color {
    #if os(iOS)
        static let timestampLabel = Color(.tertiaryLabel)
    #elseif os(macOS)
        static let timestampLabel = Color(.tertiaryLabelColor)
    #endif
}
