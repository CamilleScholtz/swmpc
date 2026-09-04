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
    @State private var feedback = ActionFeedback()

    private var isStreaming: Bool {
        switch mpd.streaming.state {
        case .loading, .playing: true
        case .stopped, .error: false
        }
    }

    private var streamingLabel: LocalizedStringResource {
        #if os(iOS)
            "Stream to iPhone"
        #elseif os(macOS)
            "Stream to this device"
        #endif
    }

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemSymbol: volume == 0 ? .speakerSlashFill : .speakerWave3Fill,
                  variableValue: volume / 100)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(.tertiary.opacity(0.65))
                .frame(width: 20, height: 16)
                .padding(3)
                .offset(y: volume == 0 ? 1 : 0)
                .animation(.snappy(duration: 0.25), value: volume == 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Volume and Outputs"))
        .accessibilityValue(Text(percentage, format: .percent.precision(.fractionLength(0))))
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: Layout.Spacing.medium) {
                VStack(alignment: .leading, spacing: Layout.Spacing.small) {
                    Text("Volume")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    HStack(spacing: Layout.Spacing.medium) {
                        Text(percentage, format: .percent.precision(.fractionLength(0)))
                        #if os(iOS)
                            .font(.caption)
                        #elseif os(macOS)
                            .font(.subheadline)
                        #endif
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
                                feedback.play(.release(.slider))

                                Task {
                                    try? await ConnectionManager.command {
                                        try await $0.setVolume(Int(volume))
                                    }
                                }
                            }
                        }
                        .controlSize(.mini)
                        .frame(minWidth: 150)
                        .accessibilityLabel(Text("Volume"))
                        .accessibilityValue(Text(percentage, format: .percent.precision(.fractionLength(0))))
                        .actionFeedback(feedback)
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
                                .symbolEffect(.variableColor.iterative, isActive: isStreaming)
                                .frame(width: 40)
                                .accessibilityHidden(true)

                            Text(streamingLabel)
                                .font(.subheadline)

                            Spacer()

                            if let server = serverManager.selectedServer {
                                @Bindable var streaming = mpd.streaming

                                Toggle(String(localized: streamingLabel), isOn: $streaming[isStreamingFrom: server])
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

                FormatSection()
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
}

private struct OutputRow: View {
    @Environment(MPD.self) private var mpd

    private let output: Output

    init(for output: Output) {
        self.output = output
    }

    var body: some View {
        @Bindable var outputs = mpd.outputs

        HStack(spacing: Layout.Spacing.medium) {
            Image(systemSymbol: output.isHttpd ? .antennaRadiowavesLeftAndRight : .speakerWave2)
                .foregroundStyle(.secondary)
                .frame(width: 40)
                .accessibilityHidden(true)

            Text(output.name)
                .font(.subheadline)

            Spacer()

            Toggle(output.name, isOn: $outputs[isEnabled: output])
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }
}

private struct FormatSection: View {
    @Environment(MPD.self) private var mpd

    var body: some View {
        let codec = mpd.status.codec
        let format = mpd.status.audioFormat
        let bitrate = mpd.status.bitrate.flatMap { $0 > 0 ? $0 : nil }

        if codec != nil || format != nil || bitrate != nil {
            Divider()

            VStack(alignment: .leading, spacing: Layout.Spacing.small) {
                Text("Format")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                if let codec {
                    FormatRow(label: "Codec", value: codec)
                }

                if let sampleRate = format?.sampleRate {
                    FormatRow(label: "Sample Rate", value: Self.description(sampleRate: sampleRate))
                }

                if let bits = format?.bits {
                    FormatRow(label: "Bit Depth", value: String(localized: "\(bits)-bit"))
                }

                if let channels = format?.channels {
                    FormatRow(label: "Channels", value: Self.description(channels: channels))
                }

                if let bitrate {
                    FormatRow(label: "Bitrate", value: String(localized: "\(bitrate.formatted()) kbps"))
                }
            }
        }
    }

    /// Formats a sample rate in kilohertz, without needless decimals.
    private static func description(sampleRate: Int) -> String {
        Measurement(value: Double(sampleRate), unit: UnitFrequency.hertz)
            .converted(to: .kilohertz)
            .formatted(.measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0 ... 1)),
            ))
    }

    /// Names the common channel layouts, and counts the rest.
    private static func description(channels: Int) -> String {
        switch channels {
        case 1: String(localized: "Mono")
        case 2: String(localized: "Stereo")
        default: String(localized: "\(channels) channels")
        }
    }
}

private struct FormatRow: View {
    let label: LocalizedStringResource
    let value: String

    var body: some View {
        HStack(spacing: Layout.Spacing.medium) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}
