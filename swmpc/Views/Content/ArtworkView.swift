//
//  ArtworkView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct ArtworkView: View {
    let image: PlatformImage?

    var animationDuration: Double = 0.2
    var aspectRatioMode: ContentMode = .fit

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
        .animation(.easeInOut(duration: animationDuration), value: image)
    }
}
