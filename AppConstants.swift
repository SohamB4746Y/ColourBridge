// MARK: - App-Wide Constants

import SwiftUI
import CoreImage

/// Centralised repository of magic numbers, layout metrics, and configuration
/// values used throughout ColourBridge.
enum AppConstants {

    // MARK: - Color Analysis

    /// Default pixel radius used when sampling the average color around a tap point.
    static let defaultSampleRadius: Int = 10

    /// RGB channel threshold above which a color is considered near-white (background).
    static let nearWhiteThreshold: CGFloat = 0.95

    /// WCAG AAA contrast ratio threshold (≥ 7:1).
    static let contrastAAA: Double = 7.0

    /// WCAG AA contrast ratio threshold (≥ 4.5:1).
    static let contrastAA: Double = 4.5

    // MARK: - Camera

    /// Minimum interval between processed camera frames (seconds).
    static let cameraFrameInterval: CFAbsoluteTime = 1.0 / 30.0

    // MARK: - Chart Rendering

    /// Intrinsic size used when rendering the built-in sample bar chart.
    static let chartImageSize = CGSize(width: 600, height: 400)

    /// Horizontal padding fraction applied to each side of the chart area.
    static let chartPaddingFraction: CGFloat = 0.15

    /// Pixel gap between consecutive chart bars.
    static let chartBarGap: CGFloat = 10

    /// Corner radius applied to the top edges of each chart bar.
    static let chartBarCornerRadius: CGFloat = 6

    /// Y-offset from the top of the chart image where bars begin.
    static let chartTopInset: CGFloat = 40

    /// Y-offset from the bottom of the chart image where bars end.
    static let chartBottomInset: CGFloat = 50

    // MARK: - Layout Metrics

    /// Standard corner radius for color swatch thumbnails.
    static let swatchCornerRadius: CGFloat = 10

    /// Side length of the color swatch in the analysis info card.
    static let swatchSize: CGFloat = 52

    /// Diameter of the tap indicator ring overlay.
    static let tapIndicatorSize: CGFloat = 44

    /// Corner radius for the floating info card background.
    static let infoCardCornerRadius: CGFloat = 20

    /// Duration (seconds) for the tap indicator ring appearance animation.
    static let tapAnimationDuration: Double = 0.25

    /// Delay (seconds) before the tap indicator ring fades out.
    static let tapIndicatorDismissDelay: Double = 0.6

    /// Outer padding applied to the welcome screen content.
    static let welcomeVerticalPadding: CGFloat = 40

    /// Inter-section spacing inside the welcome scroll view.
    static let welcomeSectionSpacing: CGFloat = 32

    /// Spacing between action buttons on the welcome screen.
    static let welcomeButtonSpacing: CGFloat = 14

    // MARK: - CVD Simulation Matrices

    /// Viénot protanopia RGB transformation row vectors.
    static let protanMatrix: (r: SIMD3<Float>, g: SIMD3<Float>, b: SIMD3<Float>) = (
        r: SIMD3<Float>(0.567, 0.433, 0.000),
        g: SIMD3<Float>(0.558, 0.442, 0.000),
        b: SIMD3<Float>(0.000, 0.242, 0.758)
    )

    /// Viénot deuteranopia RGB transformation row vectors.
    static let deutanMatrix: (r: SIMD3<Float>, g: SIMD3<Float>, b: SIMD3<Float>) = (
        r: SIMD3<Float>(0.625, 0.375, 0.000),
        g: SIMD3<Float>(0.700, 0.300, 0.000),
        b: SIMD3<Float>(0.000, 0.300, 0.700)
    )
}
