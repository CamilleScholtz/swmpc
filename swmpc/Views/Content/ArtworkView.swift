//
//  ArtworkView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct ArtworkView: View {
    let image: PlatformImage?

    var body: some View {
        Group {
            if let image {
                #if os(iOS)
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                #elseif os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                #endif
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill).opacity(0.3))
                    .aspectRatio(1.0, contentMode: .fit)
            }
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}
