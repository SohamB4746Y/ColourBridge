import UIKit
import CoreImage

// MARK: - Readability

/// WCAG-based readability rating for a color against common backgrounds.
enum Readability: String, Sendable {
    case good       = "Good"        // contrast ratio ≥ 7:1 (AAA)
    case acceptable = "Acceptable"  // contrast ratio ≥ 4.5:1 (AA)
    case low        = "Low"         // below 4.5:1
}

// MARK: - SimulationMode

/// Color-vision deficiency simulation modes.
enum SimulationMode: String, CaseIterable, Identifiable, Sendable {
    case normal = "Normal"
    case protan = "Protan"
    case deutan = "Deutan"

    var id: String { rawValue }
}

// MARK: - ColorSample

/// A single sampled color from an image, enriched with name, contrast, and readability data.
struct ColorSample: Identifiable, Sendable {
    let id = UUID()
    let uiColor: UIColor
    let location: CGPoint          // normalized 0–1 within the source image
    let name: String
    let contrastVsWhite: Double
    let contrastVsBlack: Double
    let readability: Readability
}

// MARK: - ColorAnalyzer

/// Pure-logic helpers for color sampling, naming, contrast checking,
/// and simple color-blind simulation. No UI dependencies.
struct ColorAnalyzer {

    // MARK: Average Color

    /// Sample the average color in a small region around `normalizedPoint` (0–1).
    /// `sampleRadius` is in pixels on each side of the center.
    static func averageColor(in ciImage: CIImage,
                             at normalizedPoint: CGPoint,
                             sampleRadius: Int = 10) -> UIColor? {
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        // Convert normalized point to pixel coordinates within the image extent.
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

        // Use CIAreaAverage to efficiently compute the mean color of the region.
        guard let avgFilter = CIFilter(name: "CIAreaAverage",
                                       parameters: [
                                        kCIInputImageKey: ciImage,
                                        kCIInputExtentKey: CIVector(cgRect: sampleRect)
                                       ]),
              let outputImage = avgFilter.outputImage else { return nil }

        // Render the 1×1 result into a 4-byte bitmap.
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

    // MARK: Contrast Ratio (WCAG 2.x)

    /// Returns the WCAG contrast ratio between two colors (range 1–21).
    ///
    /// Formula: (L_lighter + 0.05) / (L_darker + 0.05)
    /// where L is relative luminance per sRGB linearization.
    static func contrastRatio(_ color1: UIColor, _ color2: UIColor) -> Double {
        let l1 = relativeLuminance(of: color1)
        let l2 = relativeLuminance(of: color2)
        let lighter = max(l1, l2)
        let darker  = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Relative luminance per WCAG 2.x (sRGB linearization + BT.709 coefficients).
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

    /// Evaluate readability against both white and black backgrounds.
    /// Uses the better of the two contrast ratios.
    static func readability(for color: UIColor) -> Readability {
        let vsWhite = contrastRatio(color, .white)
        let vsBlack = contrastRatio(color, .black)
        let best = max(vsWhite, vsBlack)
        if best >= 7.0   { return .good }
        if best >= 4.5   { return .acceptable }
        return .low
    }

    // MARK: Color Naming

    /// Match `color` to the nearest entry in a curated palette and return its name.
    /// Distance is computed in sRGB Euclidean space (simple but effective for a small palette).
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

    /// A small curated palette with friendly descriptive names.
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

    // MARK: Color-Blind Simulation (Full Image)

    /// Apply a color-vision deficiency simulation to an entire `CIImage`
    /// using `CIColorMatrix`. Returns the original image when mode is `.normal`.
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

    // MARK: Color-Blind Simulation (Single Color)

    /// Approximate what `color` looks like under a given color-vision deficiency.
    ///
    /// Uses simplified Brettel/Viénot-style linear RGB transforms.
    /// Not medically precise but perceptually plausible for demonstration.
    static func simulate(_ color: UIColor, mode: SimulationMode) -> UIColor {
        guard mode != .normal else { return color }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let (sr, sg, sb): (CGFloat, CGFloat, CGFloat)

        switch mode {
        case .normal:
            return color

        case .protan:
            // Protanopia simulation matrix (Viénot 1999 approximation)
            sr = 0.567 * r + 0.433 * g + 0.000 * b
            sg = 0.558 * r + 0.442 * g + 0.000 * b
            sb = 0.000 * r + 0.242 * g + 0.758 * b

        case .deutan:
            // Deuteranopia simulation matrix (Viénot 1999 approximation)
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

    // MARK: Background Detection

    /// Returns true if the color is near-white (likely chart background, not a data bar).
    static func isNearWhite(_ color: UIColor, threshold: CGFloat = 0.95) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > threshold && g > threshold && b > threshold
    }

    // MARK: Combined Sample

    /// Full pipeline: sample a pixel region, name it, compute contrast,
    /// evaluate readability, and return a `ColorSample`.
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

