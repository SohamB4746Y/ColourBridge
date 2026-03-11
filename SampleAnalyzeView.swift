// MARK: - Sample / Photo Analysis

import SwiftUI
import CoreImage
import AVFoundation

// MARK: - SampleAnalyzeView

/// Static-image analysis screen for built-in charts and imported photos.
@MainActor
struct SampleAnalyzeView: View {

    // MARK: Properties

    /// Optional external image selected by the user from the photo library.
    var externalImage: CIImage? = nil

    /// Indicates whether the current session uses an imported image.
    private var isExternalImage: Bool { externalImage != nil }

    // MARK: State

    @State private var selectedMode: SimulationMode = .normal
    @State private var currentSample: ColorSample?
    @State private var collectedSamples: [ColorSample] = []
    @State private var tapLocation: CGPoint?
    @State private var showSummary = false

    @State private var baseCIImage: CIImage?
    @State private var chartCIImage: CIImage?
    @State private var displayUIImage: UIImage?

    // MARK: Body

    /// Main layout for image interaction and bottom analysis controls.
    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ZStack {
                    displayImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(at: location, in: geo.size)
                        }
                        .accessibilityLabel(isExternalImage ? "Imported photo" : "Sample chart")
                        .accessibilityHint("Tap on a colored area to sample it.")
                        .overlay {
                            if let loc = tapLocation {
                                TapIndicatorView(position: loc)
                            }
                        }

                    if collectedSamples.isEmpty {
                        VStack {
                            Text(isExternalImage
                                ? "Tap anywhere on the photo to sample a color"
                                : "Tap a colored bar to sample it")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(.top, 16)

                            Spacer()
                        }
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)

            AnalysisInfoCard(
                currentSample: currentSample,
                collectedSamples: collectedSamples,
                selectedMode: $selectedMode,
                showSummary: $showSummary,
                emptyLabel: "Tap a bar to sample"
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationTitle(isExternalImage ? "Photo Analysis" : "Sample Chart")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(samples: collectedSamples)
        }
        .task {
            prepareImages()
        }
        .onChange(of: selectedMode) {
            prepareImages()
        }
    }

    // MARK: Chart Data

    /// Source bars used by the built-in demo chart.
    private static let chartBars: [(UIColor, CGFloat, String)] = [
        (UIColor(red: 0.90, green: 0.15, blue: 0.15, alpha: 1), 0.85, "A"),
        (UIColor(red: 0.15, green: 0.70, blue: 0.20, alpha: 1), 0.60, "B"),
        (UIColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 1), 0.75, "C"),
        (UIColor(red: 1.00, green: 0.60, blue: 0.10, alpha: 1), 0.50, "D"),
        (UIColor(red: 0.55, green: 0.20, blue: 0.80, alpha: 1), 0.40, "E"),
        (UIColor(red: 0.00, green: 0.70, blue: 0.65, alpha: 1), 0.65, "F"),
    ]

    // MARK: Chart Renderer

    /// Renders a chart image with accessibility simulation applied to bar colors.
    ///
    /// - Parameters:
    ///   - size: Output image size.
    ///   - mode: Simulation mode applied before drawing.
    /// - Returns: Rendered `UIImage` used by the analysis view.
    private static func renderChartImage(size: CGSize = AppConstants.chartImageSize,
                                         mode: SimulationMode = .normal) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let gc = ctx.cgContext
            let bgColor = UIColor.systemBackground
            gc.setFillColor(bgColor.cgColor)
            gc.fill(CGRect(origin: .zero, size: size))

            let barCount = CGFloat(chartBars.count)
            let totalPadding = size.width * AppConstants.chartPaddingFraction
            let gap = AppConstants.chartBarGap
            let usableWidth = size.width - totalPadding
            let barWidth = (usableWidth - gap * (barCount - 1)) / barCount
            let chartTop = AppConstants.chartTopInset
            let chartBottom = size.height - AppConstants.chartBottomInset
            let chartHeight = chartBottom - chartTop

            for (i, (color, heightFrac, label)) in chartBars.enumerated() {
                let x = totalPadding / 2 + CGFloat(i) * (barWidth + gap)
                let barH = chartHeight * heightFrac
                let barRect = CGRect(x: x, y: chartBottom - barH, width: barWidth, height: barH)

                let displayColor = ColorAnalyzer.simulate(color, mode: mode)
                gc.setFillColor(displayColor.cgColor)
                let path = UIBezierPath(
                    roundedRect: barRect,
                    byRoundingCorners: [.topLeft, .topRight],
                    cornerRadii: CGSize(width: AppConstants.chartBarCornerRadius,
                                        height: AppConstants.chartBarCornerRadius)
                )
                gc.addPath(path.cgPath)
                gc.fillPath()

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.label,
                ]
                let labelStr = NSString(string: label)
                let labelSize = labelStr.size(withAttributes: attrs)
                let labelPt = CGPoint(x: x + (barWidth - labelSize.width) / 2,
                                      y: chartBottom + 8)
                labelStr.draw(at: labelPt, withAttributes: attrs)
            }

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.label,
            ]
            let title: NSString = "Sample Data by Category"
            let titleSize = title.size(withAttributes: titleAttrs)
            title.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 10),
                       withAttributes: titleAttrs)
        }
    }

    // MARK: Display Image

    /// Display image backed by either imported content or the generated sample chart.
    /// Always returns from the cached `displayUIImage` which is eagerly set in `prepareImages`.
    private var displayImage: Image {
        if let uiImage = displayUIImage {
            return Image(uiImage: uiImage)
        }
        return Image(uiImage: UIImage())
    }

    // MARK: Image Preparation

    /// Prepares render and sampling sources for the currently selected mode.
    private func prepareImages() {
        if let external = externalImage {
            if baseCIImage == nil {
                baseCIImage = external
            }
            let simulated = ColorAnalyzer.simulateImage(external, mode: selectedMode)
            chartCIImage = baseCIImage
            if let cgImg = ColorAnalyzer.sharedContext.createCGImage(
                simulated, from: simulated.extent
            ) {
                displayUIImage = UIImage(cgImage: cgImg)
            }
        } else {
            let uiImage = Self.renderChartImage(mode: selectedMode)
            displayUIImage = uiImage
            if let cg = uiImage.cgImage {
                chartCIImage = CIImage(cgImage: cg)
            }
        }
    }

    // MARK: Tap Handling

    /// Converts tap coordinates to image coordinates and records a color sample.
    ///
    /// - Parameters:
    ///   - location: Tap location in view coordinates.
    ///   - viewSize: Size of the image container view.
    private func handleTap(at location: CGPoint, in viewSize: CGSize) {
        guard let ciImage = chartCIImage else { return }

        let imageSize = ciImage.extent.size

        let fittedRect = AVMakeRect(
            aspectRatio: imageSize,
            insideRect: CGRect(origin: .zero, size: viewSize)
        )

        guard fittedRect.contains(location) else { return }

        let relativeX = location.x - fittedRect.origin.x
        let relativeY = location.y - fittedRect.origin.y

        let scaleX = imageSize.width  / fittedRect.width
        let scaleY = imageSize.height / fittedRect.height
        let pixelX = relativeX * scaleX
        let pixelY = relativeY * scaleY

        let flippedPixelY = imageSize.height - pixelY

        let normalized = CGPoint(
            x: pixelX / imageSize.width,
            y: flippedPixelY / imageSize.height
        )

        guard let rawColor = ColorAnalyzer.averageColor(in: ciImage, at: normalized),
              !ColorAnalyzer.isNearWhite(rawColor) else {
            return
        }

        withAnimation(.easeOut(duration: AppConstants.tapAnimationDuration)) {
            tapLocation = location
        }

        if let sample = ColorAnalyzer.sample(from: ciImage, at: normalized, mode: selectedMode) {
            currentSample = sample
            collectedSamples.append(sample)
            HapticEngine.sampleTap()
        }

        Task {
            try? await Task.sleep(for: .seconds(AppConstants.tapIndicatorDismissDelay))
            withAnimation { tapLocation = nil }
        }
    }
}
