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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.secondarySystemFill))
                        .frame(width: geometry.size.width, height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(.accent)
                        .frame(width: progress * geometry.size.width, height: 3)
                        .animation(.spring, value: progress)

                    Circle()
                        .fill(.accent)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isHovering ? 1.5 : 1)
                        .animation(.spring, value: isHovering)
                        .offset(x: (progress * geometry.size.width) - 4)
                        .animation(.spring, value: progress)
                }
                .compositingGroup()
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            Task(priority: .userInitiated) {
                                try? await ConnectionManager.command().seek(min(max(value.location.x / geometry.size.width, 0), 1) * (mpd.status.song?.duration ?? 100))
                            }
                        }
                )
                .onHover { value in
                    isHovering = value
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
}
