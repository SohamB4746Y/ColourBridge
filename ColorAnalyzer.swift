// MARK: - Color Analysis Engine

import UIKit
import CoreImage

// MARK: - Readability

/// WCAG-based readability classification for foreground colors against
/// common light and dark backgrounds.
enum Readability: String, Sendable {
    /// Contrast ratio ≥ 7:1 (WCAG AAA).
    case good       = "Good"
    /// Contrast ratio ≥ 4.5:1 (WCAG AA).
    case acceptable = "Acceptable"
    /// Contrast ratio < 4.5:1.
    case low        = "Low"
}

// MARK: - SimulationMode

/// Color-vision deficiency simulation modes supported by the analysis engine.
enum SimulationMode: String, CaseIterable, Identifiable, Sendable {
    case normal = "Normal"
    case protan = "Protan"
    case deutan = "Deutan"

    var id: String { rawValue }

    /// Returns the Viénot RGB row-vectors for this mode, or `nil` for normal vision.
    var matrixVectors: (r: SIMD3<Float>, g: SIMD3<Float>, b: SIMD3<Float>)? {
        switch self {
        case .normal: return nil
        case .protan: return AppConstants.protanMatrix
        case .deutan: return AppConstants.deutanMatrix
        }
    }
}

// MARK: - ColorSample

/// Immutable analysis result for a single sampled color point.
struct ColorSample: Identifiable, Sendable {
    let id = UUID()

    /// The UIColor as it would appear under the active simulation mode.
    let uiColor: UIColor

    /// Tap location in normalised image coordinates (0…1, 0…1).
    let location: CGPoint

    /// Human-readable name matched from the reference palette.
    let name: String

    /// WCAG contrast ratio against a white background.
    let contrastVsWhite: Double

    /// WCAG contrast ratio against a black background.
    let contrastVsBlack: Double

    /// Readability bucket derived from the best contrast ratio.
    let readability: Readability

    /// Hex string representation of the sampled color (e.g. "#FF4040").
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - ColorAnalyzer

/// Pure-logic helpers for color sampling, naming, contrast evaluation,
/// and color-vision deficiency simulation.
///
/// This struct contains no UI dependencies and can be tested in isolation.
struct ColorAnalyzer {

    // MARK: Shared CIContext

    /// Reusable context for all Core Image rendering operations.
    /// Creating a `CIContext` is expensive — sharing one avoids repeated allocation.
    static let sharedContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .workingColorSpace: NSNull()
    ])

    // MARK: Average Color

    /// Computes the average color in a small region around a normalised point.
    ///
    /// - Parameters:
    ///   - ciImage: Source image to sample.
    ///   - normalizedPoint: Point in normalised coordinates (0…1, 0…1).
    ///   - sampleRadius: Radius in pixels around the centre for the sampling rect.
    /// - Returns: The average `UIColor`, or `nil` when sampling fails.
    static func averageColor(in ciImage: CIImage,
                             at normalizedPoint: CGPoint,
                             sampleRadius: Int = AppConstants.defaultSampleRadius) -> UIColor? {
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
        sharedContext.render(outputImage,
                            toBitmap: &bitmap,
                            rowBytes: 4,
                            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                            format: .RGBA8,
                            colorSpace: nil)

        return UIColor(red:   CGFloat(bitmap[0]) / 255.0,
                       green: CGFloat(bitmap[1]) / 255.0,
                       blue:  CGFloat(bitmap[2]) / 255.0,
                       alpha: 1)
    }

    // MARK: Contrast Ratio (WCAG 2.x)

    /// Returns the WCAG contrast ratio between two colors (range 1…21).
    ///
    /// Uses relative luminance with sRGB linearisation per the WCAG 2.x specification.
    static func contrastRatio(_ color1: UIColor, _ color2: UIColor) -> Double {
        let l1 = relativeLuminance(of: color1)
        let l2 = relativeLuminance(of: color2)
        let lighter = max(l1, l2)
        let darker  = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Computes relative luminance after sRGB linearisation (BT.709 coefficients).
    private static func relativeLuminance(of color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        func linearize(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    // MARK: Readability

    /// Evaluates readability against both white and black backgrounds.
    ///
    /// - Parameter color: Target color to evaluate.
    /// - Returns: The readability bucket using the better of the two contrast comparisons.
    static func readability(for color: UIColor) -> Readability {
        let vsWhite = contrastRatio(color, .white)
        let vsBlack = contrastRatio(color, .black)
        let best = max(vsWhite, vsBlack)
        if best >= AppConstants.contrastAAA { return .good }
        if best >= AppConstants.contrastAA  { return .acceptable }
        return .low
    }

    // MARK: Color Naming

    /// Maps a color to the closest human-readable name from a curated palette.
    ///
    /// Distance is computed in sRGB Euclidean space — simple but effective
    /// for a small reference set.
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

    /// Curated reference palette with friendly descriptive names.
    private static let referencePalette: [(Double, Double, Double, String)] = [
        // Reds
        (0.90, 0.15, 0.15, "Deep Red"),
        (1.00, 0.40, 0.40, "Coral Red"),
        (0.80, 0.00, 0.20, "Crimson"),
        // Oranges
        (1.00, 0.60, 0.10, "Orange"),
        (1.00, 0.45, 0.00, "Dark Orange"),
        // Yellows
        (1.00, 0.90, 0.20, "Yellow"),
        (0.85, 0.75, 0.10, "Gold"),
        // Greens
        (0.15, 0.70, 0.20, "Green"),
        (0.00, 0.50, 0.25, "Dark Green"),
        (0.55, 0.85, 0.35, "Lime Green"),
        // Blue-Greens
        (0.00, 0.70, 0.65, "Teal"),
        (0.10, 0.55, 0.55, "Blue-Green"),
        // Blues
        (0.15, 0.35, 0.85, "Blue"),
        (0.10, 0.20, 0.60, "Dark Blue"),
        (0.40, 0.70, 1.00, "Sky Blue"),
        // Purples
        (0.55, 0.20, 0.80, "Purple"),
        (0.75, 0.35, 0.85, "Lavender"),
        (0.50, 0.00, 0.50, "Deep Purple"),
        // Pinks
        (1.00, 0.40, 0.70, "Pink"),
        (1.00, 0.70, 0.80, "Light Pink"),
        // Browns
        (0.55, 0.30, 0.15, "Brown"),
        (0.40, 0.25, 0.10, "Dark Brown"),
        // Neutrals
        (1.00, 1.00, 1.00, "White"),
        (0.85, 0.85, 0.85, "Light Gray"),
        (0.60, 0.60, 0.60, "Gray"),
        (0.35, 0.35, 0.35, "Dark Gray"),
        (0.10, 0.10, 0.10, "Near Black"),
        (0.00, 0.00, 0.00, "Black"),
    ]

    // MARK: CVD Simulation — Full Image

    /// Applies a color-vision deficiency simulation to an entire `CIImage`.
    ///
    /// Uses `CIColorMatrix` with the Viénot row-vectors stored in
    /// ``AppConstants``.  Returns the original image for `.normal`.
    static func simulateImage(_ image: CIImage, mode: SimulationMode) -> CIImage {
        guard let m = mode.matrixVectors else { return image }

        let rVec = CIVector(x: CGFloat(m.r.x), y: CGFloat(m.r.y), z: CGFloat(m.r.z), w: 0)
        let gVec = CIVector(x: CGFloat(m.g.x), y: CGFloat(m.g.y), z: CGFloat(m.g.z), w: 0)
        let bVec = CIVector(x: CGFloat(m.b.x), y: CGFloat(m.b.y), z: CGFloat(m.b.z), w: 0)
        let aVec = CIVector(x: 0, y: 0, z: 0, w: 1)

        guard let filter = CIFilter(name: "CIColorMatrix") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(rVec,  forKey: "inputRVector")
        filter.setValue(gVec,  forKey: "inputGVector")
        filter.setValue(bVec,  forKey: "inputBVector")
        filter.setValue(aVec,  forKey: "inputAVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")

        return filter.outputImage ?? image
    }

    // MARK: CVD Simulation — Single Color

    /// Simulates what a single color looks like under a given deficiency mode.
    ///
    /// Uses the same Viénot/Brettel-style linear RGB transforms as the image path.
    static func simulate(_ color: UIColor, mode: SimulationMode) -> UIColor {
        guard let m = mode.matrixVectors else { return color }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let sr = CGFloat(m.r.x) * r + CGFloat(m.r.y) * g + CGFloat(m.r.z) * b
        let sg = CGFloat(m.g.x) * r + CGFloat(m.g.y) * g + CGFloat(m.g.z) * b
        let sb = CGFloat(m.b.x) * r + CGFloat(m.b.y) * g + CGFloat(m.b.z) * b

        return UIColor(
            red:   min(max(sr, 0), 1),
            green: min(max(sg, 0), 1),
            blue:  min(max(sb, 0), 1),
            alpha: a
        )
    }

    // MARK: Background Detection

    /// Returns `true` when all RGB channels exceed the near-white threshold.
    static func isNearWhite(_ color: UIColor,
                            threshold: CGFloat = AppConstants.nearWhiteThreshold) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > threshold && g > threshold && b > threshold
    }

    // MARK: Combined Sample Pipeline

    /// Runs the full sampling pipeline: average → simulate → name → contrast → readability.
    ///
    /// - Parameters:
    ///   - ciImage: Source image.
    ///   - normalizedPoint: Point in normalised coordinates (0…1, 0…1).
    ///   - mode: CVD simulation mode applied before scoring.
    /// - Returns: A complete ``ColorSample`` for UI presentation, or `nil` on failure.
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
