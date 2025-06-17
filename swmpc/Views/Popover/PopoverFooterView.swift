//
//  PopoverFooterView.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/03/2025.
//

import ButtonKit
import SwiftUI

struct PopoverFooterView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()

            HStack(alignment: .center, spacing: 0) {
                RepeatView()
                    .offset(x: 10)

                Spacer()

                HStack(spacing: 2) {
                    PreviousView()
                    PauseView()
                    NextView()
                }

                Spacer()

                RandomView()
                    .offset(x: -10)
            }
            .asyncButtonStyle(.pulse)
            .opacity(0.6)
            .frame(width: 250 - 30)
            .offset(y: -4)
        }
        .frame(height: 80)
        .background(.regularMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .padding(1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: 3, x: 0, y: 2)
        .shadow(radius: 20)
    }

    struct PauseView: View {
        @Environment(MPD.self) private var mpd

        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().pause(mpd.status.isPlaying)
            } label: {
                ZStack {
                    Circle()
                        .fill(.primary)
                        .frame(width: 36, height: 36)

                    ZStack {
                        Image(systemSymbol: .pauseFill)
                            .font(.system(size: 19))
                            .scaleEffect(mpd.status.isPlaying ? 1 : 0.1)
                            .opacity(mpd.status.isPlaying ? 1 : 0.1)
                            .animation(.interactiveSpring(duration: 0.25), value: mpd.status.isPlaying)

                        Image(systemSymbol: .playFill)
                            .font(.system(size: 19))
                            .scaleEffect(mpd.status.isPlaying ? 0.1 : 1)
                            .opacity(mpd.status.isPlaying ? 0.1 : 1)
                            .animation(.interactiveSpring(duration: 0.25), value: mpd.status.isPlaying)
                    }
                    .blendMode(.destinationOut)
                }
            }
            .styledButton(hoverScale: 1.1)
        }
    }

    struct PreviousView: View {
        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().previous()
            } label: {
                Image(systemSymbol: .backwardFill)
                    .padding(10)
                    .contentShape(Circle())
            }
            .styledButton()
        }
    }

    struct NextView: View {
        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().next()
            } label: {
                Image(systemSymbol: .forwardFill)
                    .padding(10)
                    .contentShape(Circle())
            }
            .styledButton()
        }
    }

    struct RandomView: View {
        @Environment(MPD.self) private var mpd

        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().random(!(mpd.status.isRandom ?? false))
            } label: {
                ZStack {
                    Image(systemSymbol: .shuffle)
                        .foregroundColor(Color(.textColor))
                        .padding(10)

                    Circle()
                        .fill(Color(.accent))
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 12)
                        .opacity(mpd.status.isRandom ?? false ? 1 : 0)
                }
                .contentShape(Circle())
            }
            .styledButton()
        }
    }

    struct RepeatView: View {
        @Environment(MPD.self) private var mpd

        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().repeat(!(mpd.status.isRepeat ?? false))
            } label: {
                ZStack {
                    Image(systemSymbol: .repeat)
                        .foregroundColor(Color(.textColor))
                        .padding(10)

                    Circle()
                        .fill(Color(.accent))
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 12)
                        .opacity(mpd.status.isRepeat ?? false ? 1 : 0)
                }
                .contentShape(Circle())
            }
            .styledButton()
        }
    }

    struct ProgressView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false

        private var progress: CGFloat {
            guard let elapsed = mpd.status.elapsed,
                  let duration = mpd.status.song?.duration,
                  duration > 0
            else {
                return 0
            }

            return CGFloat(elapsed / duration)
        }

        var body: some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.secondarySystemFill))
                    .frame(width: 190, height: 3)

                RoundedRectangle(cornerRadius: 2)
                    .fill(.accent)
                    .frame(width: progress * 190, height: 3)
                    .animation(.spring, value: progress)

                Circle()
                    .fill(.accent)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isHovering ? 1.5 : 1)
                    .animation(.spring, value: isHovering)
                    .offset(x: (progress * 190) - 4)
                    .animation(.spring, value: progress)
            }
            .padding(.vertical, 3)
            .compositingGroup()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command().seek(min(max(value.location.x / 190, 0), 1) * (mpd.status.song?.duration ?? 100))
                        }
                    }
            )
            .onHover { value in
                isHovering = value
            }
        }
    }
}
