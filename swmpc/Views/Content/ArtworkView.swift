//
//  ArtworkView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct ArtworkView: View {
    let playable: (any Playable)?
    var aspectRatioMode: ContentMode = .fit

    @State private var image: PlatformImage?

    var body: some View {
        Group {
            if let image {
                #if os(iOS)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: aspectRatioMode)
                #elseif os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: aspectRatioMode)
                #endif
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill).opacity(0.3))
                    .aspectRatio(1.0, contentMode: aspectRatioMode)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: image)
        .task(id: playable?.id) {
            guard let playable else {
                image = nil
                return
            }

            image = try? await playable.artwork()
        }
    }
}
