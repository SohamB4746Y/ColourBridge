import UIKit
import CoreImage

/// Readability classification based on WCAG contrast thresholds.
enum Readability: String, Sendable {
    case good       = "Good"
    case acceptable = "Acceptable"
    case low        = "Low"
}

/// Supported color-vision simulation modes for analysis and rendering.
enum SimulationMode: String, CaseIterable, Identifiable, Sendable {
    case normal = "Normal"
    case protan = "Protan"
    case deutan = "Deutan"

    var id: String { rawValue }
}

/// Immutable analysis result for a sampled color point.
struct ColorSample: Identifiable, Sendable {
    let id = UUID()
    let uiColor: UIColor
    let location: CGPoint
    let name: String
    let contrastVsWhite: Double
    let contrastVsBlack: Double
    let readability: Readability
}

/// Core image and color analysis utilities used by camera and sample workflows.
struct ColorAnalyzer {

    /// Computes the average color around a normalized point in an image.
    ///
    /// - Parameters:
    ///   - ciImage: Source image to sample.
    ///   - normalizedPoint: Point in normalized coordinates (0...1, 0...1).
    ///   - sampleRadius: Radius in pixels around the point used to build the sampling rect.
    /// - Returns: Average `UIColor` for the region, or `nil` when sampling fails.
    static func averageColor(in ciImage: CIImage,
                             at normalizedPoint: CGPoint,
                             sampleRadius: Int = 10) -> UIColor? {
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        let pixelX = extent.origin.x + normalizedPoint.x * extent.width
        let pixelY = extent.origin.y + normalizedPoint.y * extent.height

        let r = CGFloat(sampleRadius)
        let sampleRect = CGRect(
            x: pixelX - r,
            y: pixelY - r,
            width: r * 2,
            height: r * 2
        ).intersection(extent)

        guard !sampleRect.isEmpty else { return nil }

        guard let avgFilter = CIFilter(name: "CIAreaAverage",
                                       parameters: [
                                        kCIInputImageKey: ciImage,
                                        kCIInputExtentKey: CIVector(cgRect: sampleRect)
                                       ]),
              let outputImage = avgFilter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let ctx = CIContext(options: [.workingColorSpace: NSNull()])
        ctx.render(outputImage,
                   toBitmap: &bitmap,
                   rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8,
                   colorSpace: nil)

        let red   = CGFloat(bitmap[0]) / 255.0
        let green = CGFloat(bitmap[1]) / 255.0
        let blue  = CGFloat(bitmap[2]) / 255.0
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    /// Returns the WCAG contrast ratio between two colors.
    ///
    /// - Parameters:
    ///   - color1: First color.
    ///   - color2: Second color.
    /// - Returns: Ratio in the inclusive range 1...21.
    static func contrastRatio(_ color1: UIColor, _ color2: UIColor) -> Double {
        let l1 = relativeLuminance(of: color1)
        let l2 = relativeLuminance(of: color2)
        let lighter = max(l1, l2)
        let darker  = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Computes relative luminance after sRGB linearization.
    private static func relativeLuminance(of color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        func linearize(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    /// Evaluates text/background readability for a color against white and black.
    ///
    /// - Parameter color: Target color to evaluate.
    /// - Returns: Readability bucket using the best contrast of white/black comparison.
    static func readability(for color: UIColor) -> Readability {
        let vsWhite = contrastRatio(color, .white)
        let vsBlack = contrastRatio(color, .black)
        let best = max(vsWhite, vsBlack)
        if best >= 7.0   { return .good }
        if best >= 4.5   { return .acceptable }
        return .low
    }

    /// Maps a color to the closest human-readable palette name.
    ///
    /// - Parameter color: Color to classify.
    /// - Returns: Name of the nearest reference color.
    static func name(for color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        var bestName = "Unknown"
        var bestDist = Double.greatestFiniteMagnitude

        for (refR, refG, refB, refName) in referencePalette {
            let dr = Double(r) - refR
            let dg = Double(g) - refG
            let db = Double(b) - refB
            let dist = dr * dr + dg * dg + db * db
            if dist < bestDist {
                bestDist = dist
                bestName = refName
            }
        }
        return bestName
    }

    private static let referencePalette: [(Double, Double, Double, String)] = [
        (0.90, 0.15, 0.15, "Deep Red"),
        (1.00, 0.40, 0.40, "Coral Red"),
        (0.80, 0.00, 0.20, "Crimson"),
        (1.00, 0.60, 0.10, "Orange"),
        (1.00, 0.45, 0.00, "Dark Orange"),
        (1.00, 0.90, 0.20, "Yellow"),
        (0.85, 0.75, 0.10, "Gold"),
        (0.15, 0.70, 0.20, "Green"),
        (0.00, 0.50, 0.25, "Dark Green"),
        (0.55, 0.85, 0.35, "Lime Green"),
        (0.00, 0.70, 0.65, "Teal"),
        (0.10, 0.55, 0.55, "Blue-Green"),
        (0.15, 0.35, 0.85, "Blue"),
        (0.10, 0.20, 0.60, "Dark Blue"),
        (0.40, 0.70, 1.00, "Sky Blue"),
        (0.55, 0.20, 0.80, "Purple"),
        (0.75, 0.35, 0.85, "Lavender"),
        (0.50, 0.00, 0.50, "Deep Purple"),
        (1.00, 0.40, 0.70, "Pink"),
        (1.00, 0.70, 0.80, "Light Pink"),
        (0.55, 0.30, 0.15, "Brown"),
        (0.40, 0.25, 0.10, "Dark Brown"),
        (1.00, 1.00, 1.00, "White"),
        (0.85, 0.85, 0.85, "Light Gray"),
        (0.60, 0.60, 0.60, "Gray"),
        (0.35, 0.35, 0.35, "Dark Gray"),
        (0.10, 0.10, 0.10, "Near Black"),
        (0.00, 0.00, 0.00, "Black"),
    ]

    /// Applies a color-vision simulation transform to an entire image.
    ///
    /// - Parameters:
    ///   - image: Source image.
    ///   - mode: Simulation mode to apply.
    /// - Returns: Simulated image, or original image when no transform is needed.
    static func simulateImage(_ image: CIImage, mode: SimulationMode) -> CIImage {
        guard mode != .normal else { return image }

        let rVec: CIVector
        let gVec: CIVector
        let bVec: CIVector

        switch mode {
        case .normal:
            return image
        case .protan:
            rVec = CIVector(x: 0.567, y: 0.433, z: 0.000, w: 0)
            gVec = CIVector(x: 0.558, y: 0.442, z: 0.000, w: 0)
            bVec = CIVector(x: 0.000, y: 0.242, z: 0.758, w: 0)
        case .deutan:
            rVec = CIVector(x: 0.625, y: 0.375, z: 0.000, w: 0)
            gVec = CIVector(x: 0.700, y: 0.300, z: 0.000, w: 0)
            bVec = CIVector(x: 0.000, y: 0.300, z: 0.700, w: 0)
        }

        let aVec = CIVector(x: 0, y: 0, z: 0, w: 1)

        guard let filter = CIFilter(name: "CIColorMatrix") else { return image }
        filter.setValue(image,  forKey: kCIInputImageKey)
        filter.setValue(rVec,   forKey: "inputRVector")
        filter.setValue(gVec,   forKey: "inputGVector")
        filter.setValue(bVec,   forKey: "inputBVector")
        filter.setValue(aVec,   forKey: "inputAVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")

        return filter.outputImage ?? image
    }

    /// Applies a color-vision simulation transform to a single color.
    ///
    /// - Parameters:
    ///   - color: Source color.
    ///   - mode: Simulation mode to apply.
    /// - Returns: Simulated output color.
    static func simulate(_ color: UIColor, mode: SimulationMode) -> UIColor {
        guard mode != .normal else { return color }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let (sr, sg, sb): (CGFloat, CGFloat, CGFloat)

        switch mode {
        case .normal:
            return color

        case .protan:
            sr = 0.567 * r + 0.433 * g + 0.000 * b
            sg = 0.558 * r + 0.442 * g + 0.000 * b
            sb = 0.000 * r + 0.242 * g + 0.758 * b

        case .deutan:
            sr = 0.625 * r + 0.375 * g + 0.000 * b
            sg = 0.700 * r + 0.300 * g + 0.000 * b
            sb = 0.000 * r + 0.300 * g + 0.700 * b
        }

        return UIColor(
            red:   min(max(sr, 0), 1),
            green: min(max(sg, 0), 1),
            blue:  min(max(sb, 0), 1),
            alpha: a
        )
    }

    /// Determines whether a sampled color is effectively near-white.
    ///
    /// - Parameters:
    ///   - color: Sampled color.
    ///   - threshold: Lower bound used for each RGB channel.
    /// - Returns: `true` when all RGB channels exceed the threshold.
    static func isNearWhite(_ color: UIColor, threshold: CGFloat = 0.95) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > threshold && g > threshold && b > threshold
    }

    /// Runs the full sampling pipeline for a point in an image.
    ///
    /// - Parameters:
    ///   - ciImage: Source image.
    ///   - normalizedPoint: Point in normalized coordinates (0...1, 0...1).
    ///   - mode: Simulation mode used before naming and scoring.
    /// - Returns: A complete `ColorSample` for UI presentation, or `nil` when sampling fails.
    static func sample(from ciImage: CIImage,
                       at normalizedPoint: CGPoint,
                       mode: SimulationMode = .normal) -> ColorSample? {
        guard let raw = averageColor(in: ciImage, at: normalizedPoint) else { return nil }

        let displayed = simulate(raw, mode: mode)
        let colorName = name(for: displayed)
        let vsWhite   = contrastRatio(displayed, .white)
        let vsBlack   = contrastRatio(displayed, .black)
        let rating    = readability(for: displayed)

        return ColorSample(
            uiColor: displayed,
            location: normalizedPoint,
            name: colorName,
            contrastVsWhite: vsWhite,
            contrastVsBlack: vsBlack,
            readability: rating
        )
    }
}
