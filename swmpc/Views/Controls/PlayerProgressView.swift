//
//  PlayerProgressView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

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
        mpd.status.song?.duration ?? 100
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
                // XXX: .mini control size is still too large.
                .introspect(.slider, on: .iOS(.v26)) { value in
                    value.sliderStyle = .thumbless
                }
            #endif
                .disabled(mpd.status.song == nil)
                .help("Seek to position in track")
                .onChange(of: elapsed) { _, value in
                    guard !isEditing else {
                        return
                    }

                    // XXX: One second animation does not work.
                    // See: https://openradar.appspot.com/FB11802261
                    withAnimation(.linear(duration: 1)) {
                        sliderValue = value
                    }
                }
                .onAppear {
                    sliderValue = elapsed
                }

            if showTimestamps {
                HStack(alignment: .center) {
                    Text(mpd.status.elapsed?.timeString ?? "0:00")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(mpd.status.song?.duration.timeString ?? "0:00")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
