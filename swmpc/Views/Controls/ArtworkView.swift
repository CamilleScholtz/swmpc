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
            private static let grainImage: CGImage? = {
                let size = 128
                var generator = SeededRandomNumberGenerator(seed: 42)
                var pixels = [UInt8](repeating: 0, count: size * size)

                for i in 0 ..< pixels.count {
                    let value = UInt8.random(in: 118 ... 138, using: &generator)
                    pixels[i] = value
                }

                guard let provider = CGDataProvider(data: Data(pixels) as CFData),
                      let image = CGImage(
                          width: size,
                          height: size,
                          bitsPerComponent: 8,
                          bitsPerPixel: 8,
                          bytesPerRow: size,
                          space: CGColorSpaceCreateDeviceGray(),
                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                          provider: provider,
                          decode: nil,
                          shouldInterpolate: false,
                          intent: .defaultIntent,
                      )
                else {
                    return nil
                }

                return image
            }()

            var body: some View {
                if let cgImage = Self.grainImage {
                    Image(decorative: cgImage, scale: 1)
                        .resizable(resizingMode: .tile)
                        .blendMode(.overlay)
                        .allowsHitTesting(false)
                }
            }
        }

        private struct SeededRandomNumberGenerator: RandomNumberGenerator {
            var state: UInt64

            init(seed: UInt64) {
                state = seed
            }

            mutating func next() -> UInt64 {
                state &+= 0x9E37_79B9_7F4A_7C15

                var z = state
                z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
                z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB

                return z ^ (z >> 31)
            }
        }
    #endif
}
