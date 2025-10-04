//
//  VolumeSliderView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/07/2025.
//

import SFSafeSymbols
import SwiftUI

struct VolumeSliderView: View {
    @Environment(MPD.self) private var mpd

    @State private var isHovering = false
    @State private var isChanging = false
    @State private var volume: Double = 0
    @State private var percentage = 0.5

    private var volumeSymbol: SFSymbol {
        let volume = Int(volume)

        if volume == 0 {
            return .speakerSlashFill
        } else if volume < 33 {
            return .speakerFill
        } else if volume < 66 {
            return .speakerWave1Fill
        } else if volume < 100 {
            return .speakerWave2Fill
        } else {
            return .speakerWave3Fill
        }
    }

    var body: some View {
        HStack(spacing: Layout.Spacing.small) {
            if isHovering {
                Slider(value: $percentage, in: 0 ... 1) {} currentValueLabel: {
                    Text("\(Int(percentage * 100))%")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 35, alignment: .trailing)
                } ticks: {
                    SliderTickContentForEach(
                        stride(from: 0.0, through: 1.0, by: 0.33).map(\.self),
                        id: \.self,
                    ) { value in
                        SliderTick(value)
                    }
                } onEditingChanged: { editing in
                    isChanging = editing
                    volume = percentage * 100

                    if !editing {
                        Task {
                            try? await ConnectionManager.command {
                                try await $0.setVolume(Int(volume))
                            }
                        }
                    }
                }
                .controlSize(.mini)
                .frame(width: 120)
                .offset(y: 1)
                .help("Adjust playback volume")
                .transition(.offset(x: 4).combined(with: .opacity))
            }

            Image(systemSymbol: volumeSymbol)
                .foregroundColor(Color(.systemFill))
                .frame(width: 20)
        }
        .animation(.spring, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear {
            volume = Double(mpd.status.volume ?? 0)
            percentage = volume / 100
        }
        .onChange(of: mpd.status.volume) { _, value in
            if !isChanging {
                volume = Double(value ?? 0)
                percentage = volume / 100
            }
        }
        .onChange(of: percentage) { _, _ in
            volume = percentage * 100
        }
    }
}
