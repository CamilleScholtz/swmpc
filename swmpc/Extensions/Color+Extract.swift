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
        
        /// Convert to LAB color space
        func toLAB() -> LAB {
            // First convert RGB to XYZ
            var rLinear = self.r
            var gLinear = self.g
            var bLinear = self.b
            
            // Apply gamma correction
            rLinear = rLinear > 0.04045 ? pow((rLinear + 0.055) / 1.055, 2.4) : rLinear / 12.92
            gLinear = gLinear > 0.04045 ? pow((gLinear + 0.055) / 1.055, 2.4) : gLinear / 12.92
            bLinear = bLinear > 0.04045 ? pow((bLinear + 0.055) / 1.055, 2.4) : bLinear / 12.92
            
            // Convert to XYZ (using D65 illuminant)
            let x = rLinear * 0.4124564 + gLinear * 0.3575761 + bLinear * 0.1804375
            let y = rLinear * 0.2126729 + gLinear * 0.7151522 + bLinear * 0.0721750
            let z = rLinear * 0.0193339 + gLinear * 0.1191920 + bLinear * 0.9503041
            
            // Normalize for D65 illuminant
            let xn = x / 0.95047
            let yn = y / 1.00000
            let zn = z / 1.08883
            
            // Convert XYZ to LAB
            let fx = xn > 0.008856 ? pow(xn, 1.0/3.0) : (7.787 * xn + 16.0/116.0)
            let fy = yn > 0.008856 ? pow(yn, 1.0/3.0) : (7.787 * yn + 16.0/116.0)
            let fz = zn > 0.008856 ? pow(zn, 1.0/3.0) : (7.787 * zn + 16.0/116.0)
            
            let labL = 116.0 * fy - 16.0
            let labA = 500.0 * (fx - fy)
            let labB = 200.0 * (fy - fz)
            
            return LAB(l: labL, a: labA, bValue: labB)
        }
    }
    
    /// LAB color space representation
    nonisolated private struct LAB {
        let l: CGFloat  // Lightness
        let a: CGFloat  // Green-Red
        let bValue: CGFloat  // Blue-Yellow
        
        /// Calculate Delta E (CIE76) distance between two LAB colors
        func distance(to other: LAB) -> CGFloat {
            let dl = self.l - other.l
            let da = self.a - other.a
            let db = self.bValue - other.bValue
            return sqrt(dl * dl + da * da + db * db)
        }
        
        /// Convert back to RGB
        func toRGB() -> RGB {
            // Convert LAB to XYZ
            let fy = (l + 16.0) / 116.0
            let fx = a / 500.0 + fy
            let fz = fy - bValue / 200.0
            
            let xn = fx * fx * fx > 0.008856 ? fx * fx * fx : (fx - 16.0/116.0) / 7.787
            let yn = fy * fy * fy > 0.008856 ? fy * fy * fy : (fy - 16.0/116.0) / 7.787
            let zn = fz * fz * fz > 0.008856 ? fz * fz * fz : (fz - 16.0/116.0) / 7.787
            
            // Denormalize for D65 illuminant
            let x = xn * 0.95047
            let y = yn * 1.00000
            let z = zn * 1.08883
            
            // Convert XYZ to RGB
            var r = x *  3.2404542 + y * -1.5371385 + z * -0.4985314
            var g = x * -0.9692660 + y *  1.8760108 + z *  0.0415560
            var b = x *  0.0556434 + y * -0.2040259 + z *  1.0572252
            
            // Apply gamma correction
            r = r > 0.0031308 ? 1.055 * pow(r, 1.0/2.4) - 0.055 : 12.92 * r
            g = g > 0.0031308 ? 1.055 * pow(g, 1.0/2.4) - 0.055 : 12.92 * g
            b = b > 0.0031308 ? 1.055 * pow(b, 1.0/2.4) - 0.055 : 12.92 * b
            
            // Clamp values
            return RGB(
                red: min(1.0, max(0.0, r)),
                green: min(1.0, max(0.0, g)),
                blue: min(1.0, max(0.0, b))
            )
        }
    }

    /// A struct to hold a color and its relative dominance (weight) in an image.
    nonisolated private struct WeightedColor: Hashable {
        let color: RGB
        let weight: CGFloat
    }
    
    /// Color extraction algorithm version
    enum ExtractionVersion: Int {
        case kMeansClustering = 1      // Version 1: Core Image k-means (current)
        case histogramQuantization = 2  // Version 2: Histogram-based quantization
        case labColorSpace = 3          // Version 3: LAB color space clustering
        case gridSampling = 4           // Version 4: Grid sampling with merging
    }

    /// Extracts a specified number of dominant colors from an image.
    ///
    /// - Parameters:
    ///   - image: The `PlatformImage` (UIImage or NSImage) to analyze.
    ///   - count: The number of distinct colors to return. Defaults to 1.
    ///   - quality: The quality of the downsampled image for analysis. Lower is faster.
    ///   - version: The algorithm version to use (1-4). Defaults to 1.
    /// - Returns: An array of SwiftUI `Color` objects, sorted by dominance.
    @concurrent
    static nonisolated func extractDominantColors(
        from image: PlatformImage,
        count: Int = 1,
        quality: CGFloat = 100.0,
        version: ExtractionVersion = .kMeansClustering
    ) async -> [Color] {
        switch version {
        case .kMeansClustering:
            return await extractDominantColorsV1_KMeans(from: image, count: count, quality: quality)
        case .histogramQuantization:
            return await extractDominantColorsV2_Histogram(from: image, count: count, quality: quality)
        case .labColorSpace:
            return await extractDominantColorsV3_LAB(from: image, count: count, quality: quality)
        case .gridSampling:
            return await extractDominantColorsV4_Grid(from: image, count: count, quality: quality)
        }
    }
    
    // MARK: - Version 1: K-Means Clustering (Current Algorithm)
    @concurrent
    private static nonisolated func extractDominantColorsV1_KMeans(
        from image: PlatformImage,
        count: Int,
        quality: CGFloat
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
        let scaleFactor = quality / max(ciImage.extent.width, ciImage.extent.height)
        let downsampledImage = ciImage.transformed(by: .init(scaleX: scaleFactor, y: scaleFactor))

        // 2. Use the k-means filter to find dominant color clusters.
        let clusterCount = max(64, count * 3)
        let kmeansFilter = CIFilter.kMeans()
        kmeansFilter.inputImage = downsampledImage
        kmeansFilter.count = clusterCount
        kmeansFilter.extent = downsampledImage.extent
        
        guard let outputImage = kmeansFilter.outputImage else {
            return []
        }

        // 3. Extract the cluster centers
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
            let alpha = CGFloat(bitmap[i * 4 + 3]) / 255.0

            if alpha > 0.001 {
                let color = RGB(red: red, green: green, blue: blue)
                weightedColors.append(WeightedColor(color: color, weight: alpha))
            }
        }

        // Sort by weight
        let sortedByWeight = weightedColors.sorted { $0.weight > $1.weight }
        
        guard !sortedByWeight.isEmpty else {
            return Array(repeating: Color.gray, count: count)
        }
        
        // Build distinct colors
        var distinctColors: [RGB] = []
        let threshold: CGFloat = 0.05
        
        for weightedColor in sortedByWeight {
            if distinctColors.count >= count { break }
            
            let color = weightedColor.color
            let isDistinct = distinctColors.isEmpty || distinctColors.allSatisfy { existing in
                color.distanceSquared(to: existing) > threshold
            }
            
            if isDistinct {
                distinctColors.append(color)
            }
        }
        
        // Fill remaining slots if needed
        while distinctColors.count < count {
            if let firstColor = distinctColors.first {
                let variation = CGFloat(distinctColors.count) * 0.1
                let variedColor = RGB(
                    red: min(1.0, max(0.0, firstColor.r + variation)),
                    green: min(1.0, max(0.0, firstColor.g + variation * 0.8)),
                    blue: min(1.0, max(0.0, firstColor.b + variation * 0.6))
                )
                distinctColors.append(variedColor)
            } else {
                distinctColors.append(RGB(red: 0.5, green: 0.5, blue: 0.5))
            }
        }
        
        // Enhance colors
        let enhancedColors = distinctColors.map { $0.enhanced() }
        
        return enhancedColors.prefix(count).map { Color(red: $0.r, green: $0.g, blue: $0.b) }
    }
    
    // MARK: - Version 2: Histogram-Based Quantization
    @concurrent
    private static nonisolated func extractDominantColorsV2_Histogram(
        from image: PlatformImage,
        count: Int,
        quality: CGFloat
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
        
        // Downsample for performance
        let maxDimension = max(cgImage.width, cgImage.height)
        let scaleFactor = min(1.0, quality / CGFloat(maxDimension))
        let newWidth = Int(CGFloat(cgImage.width) * scaleFactor)
        let newHeight = Int(CGFloat(cgImage.height) * scaleFactor)
        
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        guard let scaledImage = context.makeImage(),
              let data = scaledImage.dataProvider?.data,
              let pixels = CFDataGetBytePtr(data) else {
            return []
        }
        
        // Build color histogram with quantization (reduce color space to 32 levels per channel)
        let quantizationLevel = 8
        var histogram: [RGB: Int] = [:]
        
        for y in 0..<newHeight {
            for x in 0..<newWidth {
                let pixelIndex = (y * newWidth + x) * 4
                let r = CGFloat(pixels[pixelIndex]) / 255.0
                let g = CGFloat(pixels[pixelIndex + 1]) / 255.0
                let b = CGFloat(pixels[pixelIndex + 2]) / 255.0
                let a = CGFloat(pixels[pixelIndex + 3]) / 255.0
                
                if a > 0.5 {  // Skip transparent pixels
                    // Quantize colors
                    let qr = round(r * CGFloat(quantizationLevel)) / CGFloat(quantizationLevel)
                    let qg = round(g * CGFloat(quantizationLevel)) / CGFloat(quantizationLevel)
                    let qb = round(b * CGFloat(quantizationLevel)) / CGFloat(quantizationLevel)
                    
                    let quantizedColor = RGB(red: qr, green: qg, blue: qb)
                    histogram[quantizedColor, default: 0] += 1
                }
            }
        }
        
        // Sort by frequency
        let sortedColors = histogram.sorted { $0.value > $1.value }
        
        guard !sortedColors.isEmpty else {
            return Array(repeating: Color.gray, count: count)
        }
        
        // Select distinct colors
        var distinctColors: [RGB] = []
        let threshold: CGFloat = 0.08  // Slightly higher threshold for histogram method
        
        for (color, _) in sortedColors {
            if distinctColors.count >= count { break }
            
            let isDistinct = distinctColors.isEmpty || distinctColors.allSatisfy { existing in
                color.distanceSquared(to: existing) > threshold
            }
            
            if isDistinct {
                distinctColors.append(color)
            }
        }
        
        // Fill remaining slots
        while distinctColors.count < count {
            if let firstColor = distinctColors.first {
                let shift = CGFloat(distinctColors.count) * 0.15
                distinctColors.append(RGB(
                    red: min(1.0, max(0.0, firstColor.r + shift)),
                    green: min(1.0, max(0.0, firstColor.g - shift * 0.5)),
                    blue: min(1.0, max(0.0, firstColor.b + shift * 0.3))
                ))
            } else {
                distinctColors.append(RGB(red: 0.5, green: 0.5, blue: 0.5))
            }
        }
        
        // Sort by vibrancy for better accent colors
        let sortedByVibrancy = distinctColors.sorted { $0.vibrancy > $1.vibrancy }
        
        return sortedByVibrancy.prefix(count).map { 
            let enhanced = $0.enhanced()
            return Color(red: enhanced.r, green: enhanced.g, blue: enhanced.b) 
        }
    }
    
    // MARK: - Version 3: LAB Color Space Clustering
    @concurrent
    private static nonisolated func extractDominantColorsV3_LAB(
        from image: PlatformImage,
        count: Int,
        quality: CGFloat
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
        
        // Downsample for performance
        let maxDimension = max(cgImage.width, cgImage.height)
        let scaleFactor = min(1.0, quality / CGFloat(maxDimension))
        let newWidth = Int(CGFloat(cgImage.width) * scaleFactor)
        let newHeight = Int(CGFloat(cgImage.height) * scaleFactor)
        
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        guard let scaledImage = context.makeImage(),
              let data = scaledImage.dataProvider?.data,
              let pixels = CFDataGetBytePtr(data) else {
            return []
        }
        
        // Collect LAB colors
        var labColors: [LAB] = []
        
        // Sample pixels (skip some for performance)
        let sampleStep = max(1, Int(100.0 / quality))
        
        for y in stride(from: 0, to: newHeight, by: sampleStep) {
            for x in stride(from: 0, to: newWidth, by: sampleStep) {
                let pixelIndex = (y * newWidth + x) * 4
                let r = CGFloat(pixels[pixelIndex]) / 255.0
                let g = CGFloat(pixels[pixelIndex + 1]) / 255.0
                let b = CGFloat(pixels[pixelIndex + 2]) / 255.0
                let a = CGFloat(pixels[pixelIndex + 3]) / 255.0
                
                if a > 0.5 {
                    let rgb = RGB(red: r, green: g, blue: b)
                    labColors.append(rgb.toLAB())
                }
            }
        }
        
        guard !labColors.isEmpty else {
            return Array(repeating: Color.gray, count: count)
        }
        
        // Simple k-means clustering in LAB space
        var centroids: [LAB] = []
        
        // Initialize centroids with random colors
        for _ in 0..<min(count * 2, labColors.count) {
            if let randomColor = labColors.randomElement() {
                centroids.append(randomColor)
            }
        }
        
        // Perform k-means iterations
        for _ in 0..<5 {  // 5 iterations is usually enough
            var clusters: [[LAB]] = Array(repeating: [], count: centroids.count)
            
            // Assign colors to nearest centroid
            for color in labColors {
                var minDistance = CGFloat.infinity
                var nearestIndex = 0
                
                for (index, centroid) in centroids.enumerated() {
                    let distance = color.distance(to: centroid)
                    if distance < minDistance {
                        minDistance = distance
                        nearestIndex = index
                    }
                }
                
                clusters[nearestIndex].append(color)
            }
            
            // Update centroids
            for (index, cluster) in clusters.enumerated() {
                if !cluster.isEmpty {
                    let avgL = cluster.reduce(0) { $0 + $1.l } / CGFloat(cluster.count)
                    let avgA = cluster.reduce(0) { $0 + $1.a } / CGFloat(cluster.count)
                    let avgB = cluster.reduce(0) { $0 + $1.bValue } / CGFloat(cluster.count)
                    centroids[index] = LAB(l: avgL, a: avgA, bValue: avgB)
                }
            }
        }
        
        // Convert centroids back to RGB and sort by cluster size
        let clusterSizes = centroids.map { centroid in
            labColors.filter { $0.distance(to: centroid) < 30 }.count
        }
        
        let sortedCentroids = zip(centroids, clusterSizes)
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
        
        // Select distinct colors
        var distinctColors: [RGB] = []
        let threshold: CGFloat = 25.0  // Delta E threshold for LAB
        
        for centroid in sortedCentroids {
            if distinctColors.count >= count { break }
            
            let rgb = centroid.toRGB()
            let lab = centroid
            
            let isDistinct = distinctColors.isEmpty || distinctColors.allSatisfy { existing in
                lab.distance(to: existing.toLAB()) > threshold
            }
            
            if isDistinct {
                distinctColors.append(rgb)
            }
        }
        
        // Fill remaining slots
        while distinctColors.count < count {
            if let firstColor = distinctColors.first {
                let variation = CGFloat(distinctColors.count) * 0.12
                distinctColors.append(RGB(
                    red: min(1.0, max(0.0, firstColor.r + variation * 0.7)),
                    green: min(1.0, max(0.0, firstColor.g + variation)),
                    blue: min(1.0, max(0.0, firstColor.b - variation * 0.5))
                ))
            } else {
                distinctColors.append(RGB(red: 0.5, green: 0.5, blue: 0.5))
            }
        }
        
        // Enhance and convert to SwiftUI Colors
        return distinctColors.prefix(count).map { 
            let enhanced = $0.enhanced()
            return Color(red: enhanced.r, green: enhanced.g, blue: enhanced.b) 
        }
    }
    
    // MARK: - Version 4: Grid Sampling with Color Merging
    @concurrent
    private static nonisolated func extractDominantColorsV4_Grid(
        from image: PlatformImage,
        count: Int,
        quality: CGFloat
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
        
        // Downsample for performance
        let maxDimension = max(cgImage.width, cgImage.height)
        let scaleFactor = min(1.0, quality / CGFloat(maxDimension))
        let newWidth = Int(CGFloat(cgImage.width) * scaleFactor)
        let newHeight = Int(CGFloat(cgImage.height) * scaleFactor)
        
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        guard let scaledImage = context.makeImage(),
              let data = scaledImage.dataProvider?.data,
              let pixels = CFDataGetBytePtr(data) else {
            return []
        }
        
        // Divide image into grid cells and get average color per cell
        let gridSize = Int(sqrt(quality / 2))  // Adaptive grid based on quality
        let cellWidth = max(1, newWidth / gridSize)
        let cellHeight = max(1, newHeight / gridSize)
        
        var cellColors: [WeightedColor] = []
        
        for gridY in 0..<gridSize {
            for gridX in 0..<gridSize {
                var rSum: CGFloat = 0
                var gSum: CGFloat = 0
                var bSum: CGFloat = 0
                var pixelCount = 0
                
                let startX = gridX * cellWidth
                let startY = gridY * cellHeight
                let endX = min(startX + cellWidth, newWidth)
                let endY = min(startY + cellHeight, newHeight)
                
                for y in startY..<endY {
                    for x in startX..<endX {
                        let pixelIndex = (y * newWidth + x) * 4
                        let a = CGFloat(pixels[pixelIndex + 3]) / 255.0
                        
                        if a > 0.5 {
                            rSum += CGFloat(pixels[pixelIndex]) / 255.0
                            gSum += CGFloat(pixels[pixelIndex + 1]) / 255.0
                            bSum += CGFloat(pixels[pixelIndex + 2]) / 255.0
                            pixelCount += 1
                        }
                    }
                }
                
                if pixelCount > 0 {
                    let avgColor = RGB(
                        red: rSum / CGFloat(pixelCount),
                        green: gSum / CGFloat(pixelCount),
                        blue: bSum / CGFloat(pixelCount)
                    )
                    let weight = CGFloat(pixelCount) / CGFloat(cellWidth * cellHeight)
                    cellColors.append(WeightedColor(color: avgColor, weight: weight))
                }
            }
        }
        
        guard !cellColors.isEmpty else {
            return Array(repeating: Color.gray, count: count)
        }
        
        // Merge similar colors
        var mergedColors: [WeightedColor] = []
        let mergeThreshold: CGFloat = 0.03
        
        for cellColor in cellColors {
            var merged = false
            
            for i in 0..<mergedColors.count {
                if cellColor.color.distanceSquared(to: mergedColors[i].color) < mergeThreshold {
                    // Merge colors by weighted average
                    let totalWeight = mergedColors[i].weight + cellColor.weight
                    let w1 = mergedColors[i].weight / totalWeight
                    let w2 = cellColor.weight / totalWeight
                    
                    let mergedRGB = RGB(
                        red: mergedColors[i].color.r * w1 + cellColor.color.r * w2,
                        green: mergedColors[i].color.g * w1 + cellColor.color.g * w2,
                        blue: mergedColors[i].color.b * w1 + cellColor.color.b * w2
                    )
                    
                    mergedColors[i] = WeightedColor(color: mergedRGB, weight: totalWeight)
                    merged = true
                    break
                }
            }
            
            if !merged {
                mergedColors.append(cellColor)
            }
        }
        
        // Sort by weight (dominance)
        mergedColors.sort { $0.weight > $1.weight }
        
        // Select top colors with diversity check
        var distinctColors: [RGB] = []
        let diversityThreshold: CGFloat = 0.06
        
        for weightedColor in mergedColors {
            if distinctColors.count >= count { break }
            
            let color = weightedColor.color
            let isDistinct = distinctColors.isEmpty || distinctColors.allSatisfy { existing in
                color.distanceSquared(to: existing) > diversityThreshold
            }
            
            if isDistinct {
                distinctColors.append(color)
            }
        }
        
        // Fill remaining slots with color variations
        while distinctColors.count < count {
            if let dominantColor = distinctColors.first {
                // Create complementary or analogous colors
                let angle = CGFloat(distinctColors.count) * 0.2
                let hueShift = RGB(
                    red: min(1.0, max(0.0, dominantColor.r + cos(angle) * 0.3)),
                    green: min(1.0, max(0.0, dominantColor.g + sin(angle) * 0.3)),
                    blue: min(1.0, max(0.0, dominantColor.b - cos(angle) * 0.2))
                )
                distinctColors.append(hueShift)
            } else {
                distinctColors.append(RGB(red: 0.5, green: 0.5, blue: 0.5))
            }
        }
        
        // Apply enhancement and convert to Colors
        let enhancedColors = distinctColors.map { $0.enhanced() }
        
        // Keep dominant color first, sort rest by vibrancy
        var finalColors: [RGB] = []
        if let first = enhancedColors.first {
            finalColors.append(first)
            let accents = enhancedColors.dropFirst().sorted { $0.vibrancy > $1.vibrancy }
            finalColors.append(contentsOf: accents)
        }
        
        return finalColors.prefix(count).map { Color(red: $0.r, green: $0.g, blue: $0.b) }
    }
}
