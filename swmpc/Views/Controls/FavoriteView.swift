//
//  FavoriteView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import ButtonKit
import MPDKit
import SwiftUI

struct FavoriteView: View {
    @Environment(MPD.self) private var mpd

    @State private var isFavorited = false
    @State private var feedback = ActionFeedback()

    var body: some View {
        AsyncButton(id: ButtonNotification.favorite) {
            guard let song = mpd.status.song else {
                throw ViewError.missingData
            }

            isFavorited.toggle()
            feedback.play(isFavorited ? .success : .selection(.off))

            if isFavorited {
                try await ConnectionManager.command {
                    try await $0.add(songs: [song], to: .favorites)
                }
            } else {
                try await ConnectionManager.command {
                    try await $0.remove(songs: [song], from: .favorites)
                }
            }
        } label: {
            Image(systemSymbol: .heartFill)
                .foregroundStyle(isFavorited ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary.opacity(0.65)))
                .opacity(isFavorited ? 0.7 : 1)
                .animation(.interactiveSpring, value: isFavorited)
                .scaleEffect(isFavorited ? 1.1 : 1)
                .animation(isFavorited ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: isFavorited)
                .padding(4)
                .contentShape(Circle())
        }
        .styledButton()
        .asyncButtonStyle(.pulse)
        .disabled(mpd.status.song == nil)
        .accessibilityLabel(Text("Favorite"))
        .accessibilityValue(isFavorited ? Text("On") : Text("Off"))
        .accessibilityAddTraits(isFavorited ? .isSelected : [])
        .actionFeedback(feedback)
        .onChange(of: mpd.status.song) { _, value in
            guard let song = value else {
                return
            }

            isFavorited = mpd.playlists.favorites.contains { $0.file == song.file }
        }
        .onChange(of: mpd.playlists.favorites) { _, value in
            guard let song = mpd.status.song else {
                return
            }

            isFavorited = value.contains { $0.file == song.file }
        }
    }
}
