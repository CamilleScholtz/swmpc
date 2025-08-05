//
//  ArtworkView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct ArtworkView: View {
    let image: PlatformImage?
    var aspectRatioMode: ContentMode = .fit

    var body: some View {
        ZStack {
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
                    .fill(Color(.secondarySystemFill).opacity(0.4))
                    .aspectRatio(1.0, contentMode: aspectRatioMode)
            }
        }
    }
}
