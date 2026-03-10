import SwiftUI
import CoreImage
import AVFoundation

@MainActor
struct SampleAnalyzeView: View {

    var externalImage: CIImage? = nil

    private var isExternalImage: Bool { externalImage != nil }

    @State private var selectedMode: SimulationMode = .normal
    @State private var currentSample: ColorSample?
    @State private var collectedSamples: [ColorSample] = []
    @State private var tapLocation: CGPoint?
    @State private var showSummary = false

    @State private var baseCIImage: CIImage?
    @State private var chartCIImage: CIImage?
    @State private var displayUIImage: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                displayImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location, in: geo.size)
                    }
                    .overlay {
                        if let loc = tapLocation {
                            Circle()
                                .stroke(Color.white, lineWidth: 2.5)
                                .shadow(color: .black.opacity(0.5), radius: 3)
                                .frame(width: 44, height: 44)
                                .position(loc)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                        }
                    }
            }
            .ignoresSafeArea(edges: .bottom)

            infoCard
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .navigationTitle(isExternalImage ? "Photo Analysis" : "Sample Chart")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(samples: collectedSamples)
        }
        .onAppear {
            prepareImages()
        }
        .onChange(of: selectedMode) {
            prepareImages()
        }
    }

    private static let chartBars: [(UIColor, CGFloat, String)] = [
        (UIColor(red: 0.90, green: 0.15, blue: 0.15, alpha: 1), 0.85, "A"),
        (UIColor(red: 0.15, green: 0.70, blue: 0.20, alpha: 1), 0.60, "B"),
        (UIColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 1), 0.75, "C"),
        (UIColor(red: 1.00, green: 0.60, blue: 0.10, alpha: 1), 0.50, "D"),
        (UIColor(red: 0.55, green: 0.20, blue: 0.80, alpha: 1), 0.40, "E"),
        (UIColor(red: 0.00, green: 0.70, blue: 0.65, alpha: 1), 0.65, "F"),
    ]

    private static func renderChartImage(size: CGSize = CGSize(width: 600, height: 400),
                                         mode: SimulationMode = .normal) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let gc = ctx.cgContext
            let bgColor = UIColor.systemBackground
            gc.setFillColor(bgColor.cgColor)
            gc.fill(CGRect(origin: .zero, size: size))

            let barCount = CGFloat(chartBars.count)
            let totalPadding = size.width * 0.15
            let gap: CGFloat = 10
            let usableWidth = size.width - totalPadding
            let barWidth = (usableWidth - gap * (barCount - 1)) / barCount
            let chartTop: CGFloat = 40
            let chartBottom: CGFloat = size.height - 50
            let chartHeight = chartBottom - chartTop

            for (i, (color, heightFrac, label)) in chartBars.enumerated() {
                let x = totalPadding / 2 + CGFloat(i) * (barWidth + gap)
                let barH = chartHeight * heightFrac
                let barRect = CGRect(x: x, y: chartBottom - barH, width: barWidth, height: barH)

                let displayColor = ColorAnalyzer.simulate(color, mode: mode)
                gc.setFillColor(displayColor.cgColor)
                let path = UIBezierPath(roundedRect: barRect,
                                        byRoundingCorners: [.topLeft, .topRight],
                                        cornerRadii: CGSize(width: 6, height: 6))
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

    private var displayImage: Image {
        if let uiImage = displayUIImage {
            return Image(uiImage: uiImage)
        }
        return Image(uiImage: Self.renderChartImage(mode: selectedMode))
    }

    private func prepareImages() {
        if let external = externalImage {
            if baseCIImage == nil {
                baseCIImage = external
            }
            let simulated = ColorAnalyzer.simulateImage(external, mode: selectedMode)
            chartCIImage = baseCIImage
            let ctx = CIContext()
            if let cgImg = ctx.createCGImage(simulated, from: simulated.extent) {
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

    private var displayName: String {
        currentSample?.name ?? "Tap a bar to sample"
    }

    private var contrastText: String {
        guard let s = currentSample else { return "—" }
        let best = max(s.contrastVsWhite, s.contrastVsBlack)
        return String(format: "%.1f:1 – %@", best, s.readability.rawValue)
    }

    private var swatchColor: Color {
        if let c = currentSample?.uiColor { return Color(c) } else { return .gray }
    }

    private var infoCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(swatchColor)
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.bold())
                    Text("Contrast: \(contrastText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Picker("Simulation Mode", selection: $selectedMode) {
                ForEach(SimulationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color analysis card. Tap a bar in the chart to sample its color. Current sample: \(displayName). \(collectedSamples.count) samples collected.")
    }

    private static let chartSize = CGSize(width: 600, height: 400)

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

        withAnimation(.easeOut(duration: 0.25)) {
            tapLocation = location
        }

        if let sample = ColorAnalyzer.sample(from: ciImage, at: normalized, mode: selectedMode) {
            currentSample = sample
            collectedSamples.append(sample)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { tapLocation = nil }
        }
    }
}
