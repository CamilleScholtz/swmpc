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
    nonisolated private struct RGB: Hashable {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat

        init(red: CGFloat, green: CGFloat, blue: CGFloat) {
            self.r = red
            self.g = green
            self.b = blue
        }

        /// Calculates the squared Euclidean distance to another color.
        /// Squaring avoids the need for a costly square root operation while still being effective for comparison.
        func distanceSquared(to other: RGB) -> CGFloat {
            let dr = self.r - other.r
            let dg = self.g - other.g
            let db = self.b - other.b
            return dr * dr + dg * dg + db * db
        }
        
        /// Returns the brightness (luminance) of the color using relative luminance formula.
        var brightness: CGFloat {
            return 0.299 * r + 0.587 * g + 0.114 * b
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

    /// A struct to hold a color and its relative dominance (weight) in an image.
    nonisolated private struct WeightedColor: Hashable {
        let color: RGB
        let weight: CGFloat
    }

    /// Extracts a specified number of dominant colors from an image.
    ///
    /// - Parameters:
    ///   - image: The `PlatformImage` (UIImage or NSImage) to analyze.
    ///   - count: The number of distinct colors to return. Defaults to 1.
    ///   - quality: The quality of the downsampled image for analysis. Lower is faster.
    /// - Returns: An array of SwiftUI `Color` objects, sorted by dominance.
    @concurrent
    static nonisolated func extractDominantColors(
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

        let ciImage = CIImage(cgImage: cgImage)

        // 1. Downsample the image for performance.
        // Lanczos scale transform provides high-quality resizing.
        let scaleFactor = quality / max(ciImage.extent.width, ciImage.extent.height)
        let downsampledImage = ciImage.transformed(by: .init(scaleX: scaleFactor, y: scaleFactor))

        // 2. Use the k-means filter to find dominant color clusters.
        // We ask for more clusters than needed to have a good pool for filtering distinct colors.
        let clusterCount = max(16, count * 3)  // Increased to get more color candidates
        let kmeansFilter = CIFilter.kMeans()
        kmeansFilter.inputImage = downsampledImage
        kmeansFilter.count = clusterCount
        kmeansFilter.extent = downsampledImage.extent
        
        guard let outputImage = kmeansFilter.outputImage else {
            return []
        }

        // 3. Extract the cluster centers (the dominant colors) from the 1-pixel high output image.
        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4 * clusterCount)
        
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4 * clusterCount,
                       bounds: CGRect(x: 0, y: 0, width: clusterCount, height: 1),
                       format: .RGBA8,
                       colorSpace: ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB())

        var weightedColors: [WeightedColor] = []
        for i in 0..<clusterCount {
            let red   = CGFloat(bitmap[i * 4 + 0]) / 255.0
            let green = CGFloat(bitmap[i * 4 + 1]) / 255.0
            let blue  = CGFloat(bitmap[i * 4 + 2]) / 255.0
            let alpha = CGFloat(bitmap[i * 4 + 3]) / 255.0 // Alpha represents the weight of the cluster.

            // Skip completely transparent/invalid colors
            if alpha > 0.001 {
                let color = RGB(red: red, green: green, blue: blue)
                weightedColors.append(WeightedColor(color: color, weight: alpha))
            }
        }

        // Sort by weight (dominance) to get the most dominant color first
        let sortedByWeight = weightedColors.sorted { $0.weight > $1.weight }

        // 4. Ensure we have colors to work with
        guard !sortedByWeight.isEmpty else {
            // Return default colors if no colors were extracted
            return Array(repeating: Color.gray, count: count)
        }
        
        // Build result: dominant color first, then distinct accent colors
        var distinctColors: [RGB] = []
        
        // First pass: collect unique colors with reasonable threshold
        var seenColors = Set<RGB>()
        let initialThreshold: CGFloat = 0.05
        
        for weightedColor in sortedByWeight {
            if distinctColors.count >= count { break }
            
            let color = weightedColor.color
            
            // Check if this color is distinct enough from already selected colors
            let isDistinct = distinctColors.isEmpty || distinctColors.allSatisfy { existing in
                color.distanceSquared(to: existing) > initialThreshold
            }
            
            if isDistinct && !seenColors.contains(color) {
                distinctColors.append(color)
                seenColors.insert(color)
            }
        }
        
        // If we don't have enough colors, add variations of existing colors
        if distinctColors.count < count {
            // Try to create variations by adjusting brightness/saturation
            let existingColors = distinctColors
            
            for baseColor in existingColors {
                if distinctColors.count >= count { break }
                
                // Create a lighter variation
                let lighter = RGB(
                    red: min(1.0, baseColor.r + 0.2),
                    green: min(1.0, baseColor.g + 0.2),
                    blue: min(1.0, baseColor.b + 0.2)
                )
                
                if !distinctColors.contains(lighter) {
                    distinctColors.append(lighter)
                }
                
                if distinctColors.count >= count { break }
                
                // Create a darker variation
                let darker = RGB(
                    red: max(0.0, baseColor.r - 0.2),
                    green: max(0.0, baseColor.g - 0.2),
                    blue: max(0.0, baseColor.b - 0.2)
                )
                
                if !distinctColors.contains(darker) && darker.brightness > 0.1 {
                    distinctColors.append(darker)
                }
            }
        }
        
        // Final pass: ensure we have exactly the requested number of colors
        while distinctColors.count < count {
            // Add slight variations of the dominant color
            if let firstColor = distinctColors.first {
                let variation = CGFloat(distinctColors.count) * 0.1
                let variedColor = RGB(
                    red: min(1.0, max(0.0, firstColor.r + variation)),
                    green: min(1.0, max(0.0, firstColor.g + variation * 0.8)),
                    blue: min(1.0, max(0.0, firstColor.b + variation * 0.6))
                )
                distinctColors.append(variedColor)
            } else {
                // Fallback to gray if somehow we have no colors
                distinctColors.append(RGB(red: 0.5, green: 0.5, blue: 0.5))
            }
        }
        
        // Enhance all colors to be more vibrant
        let enhancedColors = distinctColors.map { $0.enhanced() }
        
        // Sort so dominant (first) color stays first, but accent colors are sorted by vibrancy
        var finalColors: [RGB] = []
        if let first = enhancedColors.first {
            finalColors.append(first)
            
            // Sort remaining colors by vibrancy for better accent colors
            let accents = enhancedColors.dropFirst().sorted { $0.vibrancy > $1.vibrancy }
            finalColors.append(contentsOf: accents)
        }

        return finalColors.prefix(count).map { Color(red: $0.r, green: $0.g, blue: $0.b) }
    }
}
