// MARK: - Reusable UI Components

import SwiftUI
import UIKit

// MARK: - HapticEngine

/// Lightweight wrapper around UIKit feedback generators for consistent haptics.
enum HapticEngine {
    /// Fires a light impact when a color is sampled.
    static func sampleTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Fires a medium impact for navigation actions.
    static func action() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Fires a notification feedback for results or errors.
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - ColorSwatchView

/// Displays a filled rounded rectangle representing a sampled color.
///
/// Used inside the floating info cards on both the camera and sample analysis screens.
struct ColorSwatchView: View {

    // MARK: Properties

    /// The color to display inside the swatch.
    let color: Color

    /// Optional hex string for accessibility labelling (e.g. "#FF4040").
    var hexLabel: String?

    /// Optional color name for accessibility labelling.
    var colorName: String?

    /// Side length of the square swatch. Defaults to ``AppConstants/swatchSize``.
    var size: CGFloat = AppConstants.swatchSize

    // MARK: Body

    var body: some View {
        RoundedRectangle(cornerRadius: AppConstants.swatchCornerRadius)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.swatchCornerRadius)
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
            )
            .accessibilityLabel(accessibilityText)
    }

    /// Constructs a descriptive label including color name and hex value.
    private var accessibilityText: String {
        var parts: [String] = ["Color swatch"]
        if let name = colorName { parts.append(name) }
        if let hex = hexLabel { parts.append(hex) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - TapIndicatorView

/// Animated ring that appears at the user's tap location with a spring
/// scale-in effect, then fades out.
struct TapIndicatorView: View {

    // MARK: Properties

    /// Center position in the parent coordinate space.
    let position: CGPoint

    /// Stroke line width.
    var lineWidth: CGFloat = 2.5

    // MARK: State

    @State private var appeared = false

    // MARK: Body

    var body: some View {
        Circle()
            .stroke(Color.white, lineWidth: lineWidth)
            .shadow(color: .black.opacity(0.5), radius: 3)
            .frame(width: AppConstants.tapIndicatorSize,
                   height: AppConstants.tapIndicatorSize)
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1.0 : 0.0)
            .position(position)
            .allowsHitTesting(false)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity),
                removal: .opacity
            ))
            .accessibilityHidden(true)
            .task {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    appeared = true
                }
            }
    }
}

// MARK: - AnalysisInfoCard

/// Floating card that displays the current color sample, a simulation-mode
/// picker, and a navigation button to the summary screen.
///
/// Shared between ``CameraAnalyzeView`` and ``SampleAnalyzeView``.
struct AnalysisInfoCard: View {

    // MARK: Properties

    /// Currently sampled color result, if any.
    let currentSample: ColorSample?

    /// All samples collected in this session.
    let collectedSamples: [ColorSample]

    /// Binding to the active CVD simulation mode.
    @Binding var selectedMode: SimulationMode

    /// Binding that triggers navigation to the summary screen.
    @Binding var showSummary: Bool

    /// Placeholder text shown when no sample has been taken yet.
    var emptyLabel: String = "Tap to sample"

    // MARK: Computed

    private var displayName: String {
        currentSample?.name ?? emptyLabel
    }

    private var hexText: String {
        currentSample?.hexString ?? ""
    }

    private var contrastText: String {
        guard let s = currentSample else { return "—" }
        let best = max(s.contrastVsWhite, s.contrastVsBlack)
        return String(format: "%.1f:1 – %@", best, s.readability.rawValue)
    }

    private var swatchColor: Color {
        if let c = currentSample?.uiColor { return Color(c) } else { return .gray }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 14) {
            // MARK: Sample Row
            HStack(spacing: 14) {
                ColorSwatchView(
                    color: swatchColor,
                    hexLabel: currentSample?.hexString,
                    colorName: currentSample?.name
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.bold())

                    if let sample = currentSample {
                        Text(sample.hexString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Text("Contrast: \(contrastText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // MARK: Mode Picker
            Picker("Simulation Mode", selection: $selectedMode) {
                ForEach(SimulationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Switch between normal vision, protanopia, and deuteranopia simulation.")

            // MARK: Summary Button
            Button {
                HapticEngine.action()
                showSummary = true
            } label: {
                Label("See Summary", systemImage: "chart.bar.xaxis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(collectedSamples.isEmpty)
            .accessibilityHint(collectedSamples.isEmpty
                ? "Sample at least one color first."
                : "View readability breakdown for \(collectedSamples.count) samples.")
        }
        .padding()
        .background(.ultraThinMaterial,
                     in: RoundedRectangle(cornerRadius: AppConstants.infoCardCornerRadius))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentSample?.id)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color analysis card. Current sample: \(displayName)\(hexText.isEmpty ? "" : ", \(hexText)"). \(collectedSamples.count) samples collected.")
        .accessibilitySortPriority(1)
    }
}
