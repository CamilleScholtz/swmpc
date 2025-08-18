//
//  Color+Extract.swift
//  swmpc
//
//  Created by Camille Scholtz on 15/08/2025.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

extension Color {
    /// A simple representation of a color in the RGB space for distance calculations.
    private nonisolated struct RGB: Hashable {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat

        init(red: CGFloat, green: CGFloat, blue: CGFloat) {
            r = red
            g = green
            b = blue
        }

        /// Calculates the squared Euclidean distance to another color.
        /// Squaring avoids the need for a costly square root operation while still being effective for comparison.
        func distanceSquared(to other: RGB) -> CGFloat {
            let dr = r - other.r
            let dg = g - other.g
            let db = b - other.b
            return dr * dr + dg * dg + db * db
        }

        /// Returns the brightness (luminance) of the color using relative luminance formula.
        var brightness: CGFloat {
            0.299 * r + 0.587 * g + 0.114 * b
        }

        /// Returns the saturation of the color in HSB color space.
        var saturation: CGFloat {
            let maxComponent = max(r, g, b)
            let minComponent = min(r, g, b)

            if maxComponent == 0 {
                return 0
            }

            return (maxComponent - minComponent) / maxComponent
        }

        /// Returns a vibrancy score combining brightness and saturation.
        /// Higher scores indicate more vibrant, visually appealing colors.
        var vibrancy: CGFloat {
            // Boost brightness to avoid dark colors
            // Prefer mid-to-bright colors with good saturation
            let brightnessScore = min(1.0, brightness * 1.5) // Boost brightness
            return saturation * 0.6 + brightnessScore * 0.4
        }

        /// Enhances the color to be more vibrant
        func enhanced() -> RGB {
            // Convert to HSB-like calculations for better color preservation
            let maxVal = max(r, g, b)
            let minVal = min(r, g, b)
            let delta = maxVal - minVal

            // Calculate current saturation and brightness
            let currentBrightness = maxVal
            let currentSaturation = maxVal > 0 ? delta / maxVal : 0

            // Target brightness (never too dark, never washed out)
            let targetBrightness = max(0.5, min(0.9, currentBrightness * 1.4))

            // Boost saturation for muted colors
            let targetSaturation = min(1.0, currentSaturation * 1.5 + 0.2)

            // If it's a grayscale color, just brighten it
            if currentSaturation < 0.05 {
                let gray = targetBrightness
                return RGB(red: gray, green: gray, blue: gray)
            }

            // Reconstruct color with enhanced saturation and brightness
            let brightnessFactor = targetBrightness / max(0.01, currentBrightness)

            // Apply brightness adjustment
            var newR = r * brightnessFactor
            var newG = g * brightnessFactor
            var newB = b * brightnessFactor

            // Enhance saturation by pushing colors away from gray
            let gray = (newR + newG + newB) / 3.0
            let saturationFactor = targetSaturation / max(0.01, currentSaturation)

            newR = gray + (newR - gray) * saturationFactor
            newG = gray + (newG - gray) * saturationFactor
            newB = gray + (newB - gray) * saturationFactor

            // Clamp values
            return RGB(
                red: min(1.0, max(0.0, newR)),
                green: min(1.0, max(0.0, newG)),
                blue: min(1.0, max(0.0, newB))
            )
        }
    }

    /// Extracts a specified number of dominant colors from an image using k-means clustering.
    ///
    /// - Parameters:
    ///   - image: The `PlatformImage` (UIImage or NSImage) to analyze.
    ///   - count: The number of distinct colors to return. Defaults to 1.
    ///   - quality: The quality of the downsampled image for analysis. Lower is faster.
    /// - Returns: An array of SwiftUI `Color` objects, sorted by dominance.
    @concurrent
    nonisolated static func extractDominantColors(
        from image: PlatformImage,
        count: Int = 1,
        quality: CGFloat = 100.0
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

        // Convert to CIImage and get proper color space
        let ciImage = CIImage(cgImage: cgImage)
        let colorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        // 1. Downsample the image for performance
        let scaleFactor = quality / max(ciImage.extent.width, ciImage.extent.height)
        let downsampledImage = ciImage.transformed(by: .init(scaleX: scaleFactor, y: scaleFactor))

        // 2. First pass: Get pixel data directly to analyze color distribution
        let context = CIContext()
        let width = Int(downsampledImage.extent.width)
        let height = Int(downsampledImage.extent.height)
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        context.render(downsampledImage,
                       toBitmap: &pixelData,
                       rowBytes: bytesPerRow,
                       bounds: downsampledImage.extent,
                       format: .RGBA8,
                       colorSpace: colorSpace)

        // 3. Sample colors and build a color histogram
        var colorHistogram: [RGB: Int] = [:]
        let quantizationFactor: CGFloat = 32.0 // Quantize to reduce similar colors

        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixelIndex = (y * width + x) * 4
                let r = CGFloat(pixelData[pixelIndex]) / 255.0
                let g = CGFloat(pixelData[pixelIndex + 1]) / 255.0
                let b = CGFloat(pixelData[pixelIndex + 2]) / 255.0
                let a = CGFloat(pixelData[pixelIndex + 3]) / 255.0

                if a > 0.5 {
                    // Quantize colors to reduce noise
                    let qr = round(r * quantizationFactor) / quantizationFactor
                    let qg = round(g * quantizationFactor) / quantizationFactor
                    let qb = round(b * quantizationFactor) / quantizationFactor

                    let color = RGB(red: qr, green: qg, blue: qb)
                    colorHistogram[color, default: 0] += 1
                }
            }
        }

        // 4. Sort colors by frequency and filter out browns/grays
        let sortedColors = colorHistogram.sorted { $0.value > $1.value }
            .map(\.key)
            .filter { color in
                // Filter out muddy browns and grays
                let saturation = color.saturation
                let brightness = color.brightness

                // Reject colors that are too gray (low saturation)
                if saturation < 0.15 { return false }

                // Reject very dark colors unless they're saturated
                if brightness < 0.2, saturation < 0.5 { return false }

                // Reject "brown" colors (low saturation in mid-brightness range)
                let isBrown = brightness > 0.2 && brightness < 0.6 && saturation < 0.25
                if isBrown { return false }

                return true
            }

        // 5. If we filtered out too many colors, use k-means as fallback
        let useKMeans = sortedColors.count < count * 2
        var candidateColors: [RGB] = []

        if useKMeans {
            // Use k-means filter for broader color extraction
            let clusterCount = min(16, max(8, count * 4))
            let kmeansFilter = CIFilter.kMeans()
            kmeansFilter.inputImage = downsampledImage
            kmeansFilter.count = clusterCount
            kmeansFilter.extent = downsampledImage.extent

            if let outputImage = kmeansFilter.outputImage {
                // Render k-means result
                let kmeansWidth = Int(outputImage.extent.width)
                let kmeansHeight = Int(outputImage.extent.height)
                var kmeansBitmap = [UInt8](repeating: 0, count: kmeansWidth * kmeansHeight * 4)

                context.render(outputImage,
                               toBitmap: &kmeansBitmap,
                               rowBytes: kmeansWidth * 4,
                               bounds: outputImage.extent,
                               format: .RGBA8,
                               colorSpace: colorSpace)

                // Extract unique colors from k-means result
                var kmeansColors: Set<RGB> = []
                for y in 0 ..< kmeansHeight {
                    for x in 0 ..< kmeansWidth {
                        let idx = (y * kmeansWidth + x) * 4
                        let r = CGFloat(kmeansBitmap[idx]) / 255.0
                        let g = CGFloat(kmeansBitmap[idx + 1]) / 255.0
                        let b = CGFloat(kmeansBitmap[idx + 2]) / 255.0
                        let a = CGFloat(kmeansBitmap[idx + 3]) / 255.0

                        if a > 0.5 {
                            kmeansColors.insert(RGB(red: r, green: g, blue: b))
                        }
                    }
                }

                // Sort k-means colors by vibrancy
                candidateColors = kmeansColors.sorted { $0.vibrancy > $1.vibrancy }
            }
        } else {
            candidateColors = sortedColors
        }

        // 6. Select distinct colors with better diversity
        var distinctColors: [RGB] = []
        let minDistance: CGFloat = 0.12 // Increased threshold for more distinct colors

        for color in candidateColors {
            if distinctColors.count >= count { break }

            let isDistinct = distinctColors.isEmpty || distinctColors.allSatisfy { existing in
                color.distanceSquared(to: existing) > minDistance
            }

            // Additional check: ensure color is vibrant enough (lowered threshold)
            if isDistinct, color.vibrancy > 0.25 {
                distinctColors.append(color)
            }
        }

        // 7. If we still don't have enough colors, add the most frequent ones
        if distinctColors.count < count {
            for color in candidateColors {
                if distinctColors.count >= count { break }

                // Lower the distance threshold for additional colors
                let isAcceptable = distinctColors.allSatisfy { existing in
                    color.distanceSquared(to: existing) > 0.05
                }

                if isAcceptable {
                    distinctColors.append(color)
                }
            }
        }

        // 8. Fill remaining slots with color variations if needed
        while distinctColors.count < count {
            if let primaryColor = distinctColors.first {
                // Create complementary or shifted colors
                let hueShift = CGFloat(distinctColors.count) * 0.25
                let shifted = RGB(
                    red: (primaryColor.r + hueShift).truncatingRemainder(dividingBy: 1.0),
                    green: (primaryColor.g + hueShift * 0.7).truncatingRemainder(dividingBy: 1.0),
                    blue: (primaryColor.b + hueShift * 0.4).truncatingRemainder(dividingBy: 1.0)
                )
                distinctColors.append(shifted)
            } else {
                // Fallback to a default color
                distinctColors.append(RGB(red: 0.5, green: 0.5, blue: 0.8))
            }
        }

        // 9. Enhance colors moderately to avoid muddy results without over-saturation
        let enhancedColors = distinctColors.map { color in
            // Only enhance if the color needs it
            if color.saturation < 0.4 || color.brightness < 0.4 {
                return color.enhanced()
            } else {
                // For already vibrant colors, just slight brightness adjustment
                let brightnessFactor = max(0.8, min(1.1, 1.0 + (0.5 - color.brightness) * 0.3))
                return RGB(
                    red: min(1.0, color.r * brightnessFactor),
                    green: min(1.0, color.g * brightnessFactor),
                    blue: min(1.0, color.b * brightnessFactor)
                )
            }
        }

        // 10. Sort by vibrancy to get the most appealing colors first
        let sortedByVibrancy = enhancedColors.sorted { $0.vibrancy > $1.vibrancy }

        return sortedByVibrancy.prefix(count).map { Color(red: $0.r, green: $0.g, blue: $0.b) }
    }
}