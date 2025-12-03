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
                    #if DEMO
                        .blur(radius: 8)
                        .overlay {
                            GrainOverlay()
                        }
                    #endif
                #elseif os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: aspectRatioMode)
                    #if DEMO
                        .blur(radius: 8)
                        .overlay {
                            GrainOverlay()
                        }
                    #endif
                #endif
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
                    .aspectRatio(1.0, contentMode: aspectRatioMode)
            }
        }
    }

    #if DEMO
        private struct GrainOverlay: View {
            var body: some View {
                Canvas { context, size in
                    for _ in 0 ..< Int(size.width * size.height * 0.5) {
                        let x = Double.random(in: 0 ..< size.width)
                        let y = Double.random(in: 0 ..< size.height)
                        let opacity = Double.random(in: 0.05 ... 0.15)

                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(.white.opacity(opacity)),
                        )
                    }
                }
                .blendMode(.overlay)
                .allowsHitTesting(false)
            }
        }
    #endif
}
