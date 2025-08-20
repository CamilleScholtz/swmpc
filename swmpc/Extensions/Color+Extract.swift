//
//  Color+Extract.swift
//  swmpc
//
//  Created by Camille Scholtz on 15/08/2025.
//

import CoreImage
import SwiftUI

#if os(macOS)
    /// Platform-specific color type for macOS
    typealias PlatformColor = NSColor
#else
    /// Platform-specific color type for iOS
    typealias PlatformColor = UIColor
#endif

/// Extension providing dominant color extraction functionality from images.
extension Color {
    private nonisolated enum Constants {
        /// Quantization level for color histogram.
        static let quantization: CGFloat = 32.0
        /// Minimum alpha for non-transparent pixels.
        static let minAlpha: CGFloat = 0.5
        /// Brightness range for acceptable colors.
        static let brightnessRange: ClosedRange<CGFloat> = 0.2 ... 0.7
        /// Minimum saturation for vibrant colors.
        static let minSaturation: CGFloat = 0.4
        /// Minimum vibrancy score for candidate colors.
        static let vibrancyThreshold: CGFloat = 0.3
        /// Minimum squared distance between distinct colors.
        static let minColorDistanceSquared: CGFloat = 0.01
        /// Maximum pixels to sample (long side).
        static let maxSampleSize: CGFloat = 100.0
        /// Color adjustment scales.
        static let enhancementScale: (brightness: CGFloat, saturation:
            CGFloat) = (1.1, 1.5)
        /// BT.709 luma weights for perceptual brightness.
        static let lumaWeights: (r: CGFloat, g: CGFloat, b:
            CGFloat) = (0.2126, 0.7152, 0.0722)
        /// Pre-calculated reciprocal for byte-to-float conversion.
        static let inv255: CGFloat = 1.0 / 255.0
    }

    /// Shared Core Image context pinned to sRGB for consistent color handling.
    private nonisolated static let context: CIContext = {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        ]

        return CIContext(options: options)
    }()

    /// RGB color representation with color analysis capabilities.
    private nonisolated struct RGB: Hashable {
        /// Red component (0.0 to 1.0).
        let r: CGFloat
        /// Green component (0.0 to 1.0).
        let g: CGFloat
        /// Blue component (0.0 to 1.0).
        let b: CGFloat

        /// Calculates perceived brightness using BT.709 luma coefficients.
        var brightness: CGFloat {
            Constants.lumaWeights.r * r + Constants.lumaWeights.g * g +
                Constants.lumaWeights.b * b
        }

        /// Calculates color saturation (0.0 = grayscale, 1.0 = fully saturated)
        /// Uses the difference between max and min RGB values.
        var saturation: CGFloat {
            let maxVal = max(r, g, b)
            let minVal = min(r, g, b)

            return maxVal > 0 ? (maxVal - minVal) / maxVal : 0
        }

        /// Calculates color vibrancy combining saturation and brightness.
        var vibrancy: CGFloat {
            saturation * 0.7 + min(1.0, brightness * 1.2) * 0.3
        }

        /// Calculates Euclidean distance to another RGB color.
        ///
        /// - Parameter other: The color to compare with
        /// - Returns: Squared Euclidean distance
        func distance(to other: RGB) -> CGFloat {
            let dr = r - other.r
            let dg = g - other.g
            let db = b - other.b

            return dr * dr + dg * dg + db * db
        }

        /// Adjusts color brightness and/or saturation using platform color
        /// APIs.
        ///
        /// - Parameters:
        ///   - brightnessScale: Multiplier for brightness adjustment.
        ///   - saturationScale: Multiplier for saturation adjustment
        /// - Returns: Adjusted RGB color.
        func adjusted(brightness brightnessScale: CGFloat = 1.0,
                      saturation saturationScale: CGFloat = 1.0) -> RGB
        {
            let color = PlatformColor(red: r, green: g, blue: b, alpha: 1.0)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

            let newBrightness = max(Constants.brightnessRange.lowerBound,
                                    min(Constants.brightnessRange.upperBound,
                                        b * brightnessScale))
            let newSaturation = max(Constants.minSaturation, min(1.0, s *
                    saturationScale))

            let adjusted = PlatformColor(hue: h, saturation: newSaturation,
                                         brightness: newBrightness, alpha: 1.0)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
            adjusted.getRed(&red, green: &green, blue: &blue, alpha: &a)

            return RGB(r: red, g: green, b: blue)
        }
    }

    /// Builds a histogram of quantized colors using vectorized operations.
    ///
    /// - Parameters:
    ///   - pixels: Buffer containing RGBA pixel data.
    ///   - width: Image width in pixels.
    ///   - height: Image height in pixels.
    /// - Returns: Array of scored and filtered RGB colors.
    private nonisolated static func buildScoredHistogram(
        from pixels: UnsafeBufferPointer<UInt8>,
        width: Int,
        height: Int,
    ) -> [(color: RGB, score: CGFloat)] {
        let pixelCount = width * height
        var histogram = [RGB: Int]()
        histogram.reserveCapacity(min(pixelCount / 16, 1000))

        let quantize = Constants.quantization
        let inv255 = Constants.inv255

        for y in 0 ..< height {
            let rowStart = y * width * 4
            for x in 0 ..< width {
                let i = rowStart + x * 4

                let a = CGFloat(pixels[i + 3]) * inv255
                guard a > Constants.minAlpha else { continue }

                let r = round(CGFloat(pixels[i]) * inv255 * quantize) / quantize
                let g = round(CGFloat(pixels[i + 1]) * inv255 * quantize) / quantize
                let b = round(CGFloat(pixels[i + 2]) * inv255 * quantize) / quantize

                let color = RGB(r: r, g: g, b: b)
                histogram[color, default: 0] += 1
            }
        }

        return histogram.compactMap { color, frequency in
            let vibrancy = color.vibrancy
            guard vibrancy > Constants.vibrancyThreshold,
                  color.saturation > 0.1 || color.brightness > 0.2
            else {
                return nil
            }

            let score = log(CGFloat(frequency) + 1.0) * vibrancy

            return (color: color, score: score)
        }.sorted { $0.score > $1.score }
    }

    /// Extracts dominant colors from an image using histogram analysis.
    ///
    /// - Parameters:
    ///   - image: The source image to extract colors from.
    ///   - count: Number of dominant colors to extract (default: 1).
    ///   - quality: Sampling quality from 1-100, higher values process more
    ///              pixels (default: 100).
    /// - Returns: Array of dominant colors sorted by vibrancy, or empty array
    ///            if extraction fails.
    @concurrent
    nonisolated static func extractDominantColors(
        from image: PlatformImage,
        count: Int = 1,
        quality: CGFloat = Constants.maxSampleSize,
    ) async -> [Color] {
        #if os(iOS)
            guard let cgImage = image.cgImage else {
                return []
            }
        #elseif os(macOS)
            guard let cgImage = image.cgImage(forProposedRect: nil, context:
                nil, hints: nil)
            else {
                return []
            }
        #endif

        let ciImage = CIImage(cgImage: cgImage)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ??
            CGColorSpaceCreateDeviceRGB()

        let imageLongSide = max(ciImage.extent.width, ciImage.extent.height)
        let targetLongSide = min(quality, imageLongSide)
        let scale = targetLongSide / imageLongSide
        guard scale > 0 else {
            return []
        }

        let scaled = ciImage.transformed(by: .init(scaleX: scale, y: scale))

        let width = Int(scaled.extent.width)
        let height = Int(scaled.extent.height)
        guard width > 0, height > 0 else {
            return []
        }

        let bytesPerRow = width * 4
        let pixelCount = height * bytesPerRow
        var pixels = [UInt8](repeating: 0, count: pixelCount)

        context.render(scaled,
                       toBitmap: &pixels,
                       rowBytes: bytesPerRow,
                       bounds: scaled.extent,
                       format: .RGBA8,
                       colorSpace: colorSpace)

        let candidates = pixels.withUnsafeBufferPointer { buffer in
            buildScoredHistogram(from: buffer, width: width, height: height)
        }

        var result: [RGB] = []
        result.reserveCapacity(count)

        for candidate in candidates {
            if result.count >= count {
                break
            }

            let isDistinct = result.allSatisfy { existing in
                candidate.color.distance(to: existing) >
                    Constants.minColorDistanceSquared
            }

            if isDistinct {
                result.append(candidate.color)
            }
        }

        while result.count < count {
            if let primary = result.first {
                let factor = 1.0 - (CGFloat(result.count) * 0.15)
                result.append(primary.adjusted(brightness: factor))
            } else {
                result.append(RGB(r: 0.5, g: 0.5, b: 0.5))
            }
        }

        return result.map { color in
            let needsEnhancement = color.saturation < 0.5 ||
                color.brightness < 0.4
            let final = needsEnhancement ?
                color.adjusted(brightness: Constants.enhancementScale.brightness,
                               saturation: Constants.enhancementScale.saturation) : color

            return Color(.sRGB, red: final.r, green: final.g, blue: final.b, opacity: 1)
        }
    }
}
