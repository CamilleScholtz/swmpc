//
//  PlayerProgressView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import SwiftUI

struct PlayerProgressView: View {
    @Environment(MPD.self) private var mpd

    var showTimestamps: Bool = true

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
                    isEditing = editing
                    if !editing {
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command().seek(sliderValue)
                        }
                    }
                },
            )
            .controlSize(.mini)
            .onChange(of: elapsed) { _, newValue in
                if !isEditing {
                    sliderValue = newValue
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
