//
//  OutputView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/07/2025.
//

import MPDKit
import SFSafeSymbols
import SwiftUI

struct OutputView: View {
    @Environment(MPD.self) private var mpd
    @Environment(ServerManager.self) private var serverManager

    @State private var showPopover = false

    @State private var isChangingVolume = false
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
        Button {
            showPopover.toggle()
        } label: {
            Image(systemSymbol: volumeSymbol)
                .foregroundColor(Color(.systemFill))
                .frame(width: 20, height: 16)
                .padding(3)
                .offset(y: volume == 0 ? 1 : 0)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: Layout.Spacing.medium) {
                VStack(alignment: .leading, spacing: Layout.Spacing.small) {
                    Text("Volume")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    HStack(spacing: Layout.Spacing.medium) {
                        Text("\(Int(percentage * 100))%")
                        #if os(iOS)
                            .font(.subheadline.pointSize(12))
                        #elseif os(macOS)
                            .font(.subheadline)
                        #endif
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40)

                        Slider(value: $percentage, in: 0 ... 1) {} ticks: {
                            SliderTickContentForEach(
                                stride(from: 0.0, through: 1.0, by: 0.25).map(\.self),
                                id: \.self,
                            ) { value in
                                SliderTick(value)
                            }
                        } onEditingChanged: { editing in
                            isChangingVolume = editing
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
                        .frame(minWidth: 150)
                    }
                }

                if !mpd.outputs.outputs.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: Layout.Spacing.small) {
                        Text("Outputs")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        ForEach(mpd.outputs.outputs, id: \.id) { output in
                            OutputRow(for: output)
                        }
                    }
                }

                if !mpd.outputs.httpd.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: Layout.Spacing.small) {
                        Text("Streaming")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        HStack(spacing: Layout.Spacing.medium) {
                            Image(systemSymbol: .antennaRadiowavesLeftAndRight)
                                .foregroundStyle(.secondary)
                                .frame(width: 40)

                            #if os(iOS)
                                Text("Stream to iPhone")
                                    .font(.subheadline)
                            #elseif os(macOS)
                                Text("Stream to this device")
                                    .font(.subheadline)
                            #endif

                            Spacer()

                            if let server = serverManager.selectedServer {
                                Toggle("", isOn: Binding(
                                    get: { mpd.streaming.state != .stopped },
                                    set: { _ in mpd.streaming.toggleStreaming(from: server) },
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .disabled(!mpd.outputs.httpd.contains { $0.isEnabled })
                            }
                        }

                        if case let .error(message) = mpd.streaming.state {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding()
            #if os(iOS)
                .presentationCompactAdaptation(.popover)
            #endif
        }
        .onAppear {
            volume = Double(mpd.status.volume ?? 0)
            percentage = volume / 100
        }
        .onChange(of: mpd.status.volume) { _, value in
            if !isChangingVolume, let value {
                volume = Double(value)
                percentage = volume / 100
            }
        }
        .onChange(of: percentage) { _, _ in
            volume = percentage * 100
        }
    }

    private struct OutputRow: View {
        @Environment(MPD.self) private var mpd

        private let output: Output

        init(for output: Output) {
            self.output = output
        }

        var body: some View {
            HStack(spacing: Layout.Spacing.medium) {
                Image(systemSymbol: output.isHttpd ? .antennaRadiowavesLeftAndRight : .speakerWave2)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)

                Text(output.name)
                    .font(.subheadline)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { output.isEnabled },
                    set: { _ in
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command {
                                try await $0.toggleOutput(output)
                            }

                            try? await mpd.outputs.set(idle: false)
                        }
                    },
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
        }
    }
}
