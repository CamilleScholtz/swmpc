//
//  VolumeSliderView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/07/2025.
//

import SFSafeSymbols
import SwiftUI
import SwiftUIIntrospect

struct VolumeSliderView: View {
    @Environment(MPD.self) private var mpd

    @State private var isHovering = false
    @State private var isChanging = false
    @State private var volume: Double = 0

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
        HStack(spacing: 6) {
            if isHovering {
                HStack(spacing: 4) {
                    Slider(value: $volume, in: 0 ... 100, step: 1, onEditingChanged: { editing in
                        isChanging = editing

                        if !editing {
                            Task {
                                try? await ConnectionManager.command().setVolume(Int(volume))
                            }
                        }
                    })
                    .controlSize(.mini)
                    .introspect(.slider, on: .macOS(.v15)) {
                        $0.numberOfTickMarks = 1
                    }
                    .frame(width: 80)

                    Text("\(Int(volume))%")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 35, alignment: .trailing)
                }
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
        }
        .onChange(of: mpd.status.volume) { _, value in
            if !isChanging {
                volume = Double(value ?? 0)
            }
        }
    }
}
