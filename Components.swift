// MARK: - Reusable UI Components

import SwiftUI

// MARK: - ColorSwatchView

/// Displays a filled rounded rectangle representing a sampled color.
///
/// Used inside the floating info cards on both the camera and sample analysis screens.
struct ColorSwatchView: View {

    // MARK: Properties

    /// The color to display inside the swatch.
    let color: Color

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
    }
}

// MARK: - TapIndicatorView

/// Animated ring that appears at the user's tap location, then fades out.
struct TapIndicatorView: View {

    // MARK: Properties

    /// Center position in the parent coordinate space.
    let position: CGPoint

    /// Stroke line width.
    var lineWidth: CGFloat = 2.5

    // MARK: Body

    var body: some View {
        Circle()
            .stroke(Color.white, lineWidth: lineWidth)
            .shadow(color: .black.opacity(0.5), radius: 3)
            .frame(width: AppConstants.tapIndicatorSize,
                   height: AppConstants.tapIndicatorSize)
            .position(position)
            .allowsHitTesting(false)
            .transition(.opacity)
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
                ColorSwatchView(color: swatchColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.bold())
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

            // MARK: Summary Button
            Button {
                showSummary = true
            } label: {
                Label("See Summary", systemImage: "chart.bar.xaxis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(collectedSamples.isEmpty)
        }
        .padding()
        .background(.ultraThinMaterial,
                     in: RoundedRectangle(cornerRadius: AppConstants.infoCardCornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color analysis card. Current sample: \(displayName). \(collectedSamples.count) samples collected.")
    }
}
