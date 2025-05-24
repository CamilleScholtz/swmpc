//
//  AsyncArtworkView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct AsyncArtworkView: View {
    let playable: (any Playable)?
    var aspectRatioMode: ContentMode = .fit

    @State private var image: PlatformImage?
    @State private var isLoading = false

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
        .task(id: playable?.id) {
            guard let playable, !isLoading else {
                return
            }

            isLoading = true
            defer { isLoading = false }

            image = try? await playable.loadArtwork()
        }
    }
}
