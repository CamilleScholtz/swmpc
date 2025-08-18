//
//  Color+Extract.swift
//  swmpc
//
//  Created by Camille Scholtz on 15/08/2025.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

#if os(macOS)
    typealias PlatformColor = NSColor
#else
    typealias PlatformColor = UIColor
#endif

extension Color {
    private nonisolated static let context = CIContext()

    private nonisolated struct RGB: Hashable {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat

        var brightness: CGFloat {
            0.3 * r + 0.6 * g + 0.1 * b
        }

        var saturation: CGFloat {
            let maxVal = max(r, g, b)
            let minVal = min(r, g, b)
            
            return maxVal > 0 ? (maxVal - minVal) / maxVal : 0
        }

        var vibrancy: CGFloat {
            saturation * 0.7 + min(1.0, brightness * 1.2) * 0.3
        }

        func distance(to other: RGB) -> CGFloat {
            let dr = r - other.r
            let dg = g - other.g
            let db = b - other.b
            
            return dr * dr + dg * dg + db * db
        }

        func enhanced() -> RGB {
            let color = PlatformColor(red: r, green: g, blue: b, alpha: 1.0)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

            // Adjust brightness and saturation - boost saturation more
            let newBrightness = max(0.45, min(0.75, b * 1.15))
            let newSaturation = min(1.0, max(0.4, s * 1.5 + 0.1))

            let enhanced = PlatformColor(hue: h, saturation: newSaturation, brightness: newBrightness, alpha: 1.0)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
            enhanced.getRed(&red, green: &green, blue: &blue, alpha: &a)

            return RGB(r: red, g: green, b: blue)
        }

        // Create harmonious variations
        func createVariation(factor: CGFloat) -> RGB {
            let color = PlatformColor(red: r, green: g, blue: b, alpha: 1.0)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

            // Create variation by adjusting brightness
            let newBrightness = max(0.2, min(1.0, b * factor))
            let varied = PlatformColor(hue: h, saturation: s, brightness: newBrightness, alpha: 1.0)

            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
            varied.getRed(&red, green: &green, blue: &blue, alpha: &a)

            return RGB(r: red, g: green, b: blue)
        }
    }

    // Helper function to process pixel buffer and build histogram
    private nonisolated static func buildColorHistogram(
        from pixels: [UInt8],
        count: Int,
        quantize: CGFloat = 32.0,
    ) -> [RGB: Int] {
        var histogram = [RGB: Int](minimumCapacity: min(count / 16, 1000))

        pixels.withUnsafeBufferPointer { buffer in
            for i in stride(from: 0, to: count, by: 4) {
                let a = CGFloat(buffer[i + 3]) / 255.0
                guard a > 0.5 else {
                    continue
                }

                let r = round(CGFloat(buffer[i]) / 255.0 * quantize) / quantize
                let g = round(CGFloat(buffer[i + 1]) / 255.0 * quantize) / quantize
                let b = round(CGFloat(buffer[i + 2]) / 255.0 * quantize) / quantize

                let color = RGB(r: r, g: g, b: b)
                histogram[color, default: 0] += 1
            }
        }

        return histogram
    }

    @concurrent
    nonisolated static func extractDominantColors(
        from image: PlatformImage,
        count: Int = 1,
        quality: CGFloat = 100.0,
    ) async -> [Color] {
        #if os(macOS)
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return []
            }
        #else
            guard let cgImage = image.cgImage else {
                return []
            }
        #endif

        let ciImage = CIImage(cgImage: cgImage)
        let colorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        let scale = quality / max(ciImage.extent.width, ciImage.extent.height)
        let scaled = ciImage.transformed(by: .init(scaleX: scale, y: scale))

        let width = Int(scaled.extent.width)
        let height = Int(scaled.extent.height)
        let bytesPerRow = width * 4
        let pixelCount = height * bytesPerRow
        var pixels = [UInt8](repeating: 0, count: pixelCount)

        context.render(scaled,
                       toBitmap: &pixels,
                       rowBytes: bytesPerRow,
                       bounds: scaled.extent,
                       format: .RGBA8,
                       colorSpace: colorSpace)

        // Use helper function to build histogram
        let histogram = buildColorHistogram(from: pixels, count: pixelCount)

        // Score colors by frequency and vibrancy instead of strict filtering
        let scoredColors = histogram.map { color, frequency in
            // Use logarithmic scale for frequency to prevent overwhelming dominant colors
            let freqScore = log(CGFloat(frequency) + 1.0)
            let score = freqScore * color.vibrancy
            return (color: color, score: score, frequency: frequency)
        }

        // Sort by score and filter out very poor colors
        var candidates = scoredColors
            .filter { $0.color.saturation > 0.1 || $0.color.brightness > 0.2 }
            .sorted { $0.score > $1.score }
            .map(\.color)

        if candidates.count < count * 2 {
            let filter = CIFilter.kMeans()
            filter.inputImage = scaled
            filter.count = min(16, max(8, count * 4))
            filter.extent = scaled.extent

            if let output = filter.outputImage {
                let kWidth = Int(output.extent.width)
                let kHeight = Int(output.extent.height)
                let kPixelCount = kWidth * kHeight * 4
                var kPixels = [UInt8](repeating: 0, count: kPixelCount)

                context.render(output,
                               toBitmap: &kPixels,
                               rowBytes: kWidth * 4,
                               bounds: output.extent,
                               format: .RGBA8,
                               colorSpace: colorSpace)

                // Use helper function for k-means histogram too
                let kHistogram = buildColorHistogram(from: kPixels, count: kPixelCount, quantize: 255.0)
                candidates = kHistogram.keys.sorted { $0.vibrancy > $1.vibrancy }
            }
        }

        var result: [RGB] = []
        let minDist: CGFloat = 0.1

        for color in candidates {
            if result.count >= count { break }

            let distinct = result.isEmpty || result.allSatisfy {
                color.distance(to: $0) > minDist
            }

            if distinct, color.vibrancy > 0.3 {
                result.append(color)
            }
        }

        while result.count < count {
            if let first = result.first {
                // Use the new createVariation method for harmonious colors
                let factor = 1.0 - (CGFloat(result.count) * 0.15)
                result.append(first.createVariation(factor: factor))
            } else {
                result.append(RGB(r: 0.5, g: 0.5, b: 0.8))
            }
        }

        let enhanced = result.map { color in
            color.saturation < 0.5 || color.brightness < 0.4 ? color.enhanced() : color
        }

        return enhanced.sorted { $0.vibrancy > $1.vibrancy }
            .prefix(count)
            .map { Color(red: $0.r, green: $0.g, blue: $0.b) }
    }
}
