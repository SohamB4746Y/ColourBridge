// MARK: - Summary View

import SwiftUI
import Charts

// MARK: - ReadabilityBucket

/// Lightweight chart model representing one readability category bucket.
private struct ReadabilityBucket: Identifiable, Sendable {
    let category: String
    let count: Int
    var id: String { category }
}

// MARK: - SummaryView

/// Presents aggregated readability metrics for sampled colors.
@MainActor
struct SummaryView: View {

    // MARK: Properties

    /// Collected samples from camera or static-image workflows.
    let samples: [ColorSample]
    @Environment(\.dismiss) private var dismiss

    // MARK: Animation State

    @State private var chartAppeared = false

    // MARK: Computed Properties

    /// Number of samples meeting at least AA readability.
    private var readableCount: Int {
        samples.filter { $0.readability == .good || $0.readability == .acceptable }.count
    }

    /// Number of samples below acceptable readability.
    private var hardToReadCount: Int {
        samples.filter { $0.readability == .low }.count
    }

    /// Data points used by the summary bar chart.
    private var chartData: [ReadabilityBucket] {
        [
            ReadabilityBucket(category: "Readable", count: readableCount),
            ReadabilityBucket(category: "Hard to Read", count: hardToReadCount),
        ]
    }

    // MARK: Body

    /// Main summary layout containing chart, samples, explanation, and restart action.
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                chartSection

                if !samples.isEmpty {
                    sampleListSection
                }

                explanationSection

                Button {
                    HapticEngine.action()
                    dismiss()
                } label: {
                    Label("Restart Demo", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
                chartAppeared = true
            }
        }
    }

    // MARK: Chart Section

    /// Bar chart section visualizing readability distribution.
    /// Uses blue/orange (CVD-safe) palette with pattern marks for additional differentiation.
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Readability Overview")
                .font(.title3.bold())
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            Chart(chartData) { bucket in
                BarMark(
                    x: .value("Category", bucket.category),
                    y: .value("Count", chartAppeared ? bucket.count : 0)
                )
                .foregroundStyle(bucket.category == "Readable"
                    ? Color.blue
                    : Color.orange)
                .cornerRadius(AppConstants.chartBarCornerRadius)
                .annotation(position: .top) {
                    if chartAppeared {
                        Text("\(bucket.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .accessibilityLabel("\(bucket.category): \(bucket.count) sample\(bucket.count == 1 ? "" : "s")")
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
            .padding(.horizontal)
            .animation(.easeOut(duration: 0.7), value: chartAppeared)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Bar chart showing \(readableCount) readable and \(hardToReadCount) hard to read samples.")
        }
    }

    // MARK: Sample List Section

    /// Scrollable list of collected color samples with swatches and contrast info.
    private var sampleListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Collected Samples")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Text("\(samples.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.secondary))
                    .accessibilityLabel("\(samples.count) total")
            }
            .padding(.horizontal)

            LazyVStack(spacing: 8) {
                ForEach(samples) { sample in
                    HStack(spacing: 12) {
                        ColorSwatchView(
                            color: Color(sample.uiColor),
                            hexLabel: sample.hexString,
                            colorName: sample.name,
                            size: 36
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(sample.name)
                                .font(.subheadline.weight(.medium))
                            Text(sample.hexString)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        readabilityBadge(for: sample.readability)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: Readability Badge

    /// Compact colored badge indicating readability level.
    private func readabilityBadge(for level: Readability) -> some View {
        let (text, color): (String, Color) = switch level {
        case .good:       ("AAA", .blue)
        case .acceptable: ("AA",  .cyan)
        case .low:        ("Low", .orange)
        }
        return Text(text)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
            .accessibilityLabel(level.rawValue)
    }

    // MARK: Explanation Section

    /// Explanatory copy contextualizing the current session results.
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if samples.isEmpty {
                Text("No samples were collected. Go back and tap some colors to see results here.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Group {
                    Text("You sampled **\(samples.count)** color\(samples.count == 1 ? "" : "s") in this session.")

                    if hardToReadCount > 0 {
                        Text("**\(hardToReadCount)** of those had low contrast and may be hard to distinguish for people with color‑vision deficiencies.")
                    } else {
                        Text("All sampled colors met at least a \(String(format: "%.1f", AppConstants.contrastAA)) : 1 contrast ratio — great for readability!")
                    }

                    Text("Adding labels, patterns, or textures alongside color makes information accessible to everyone, regardless of how they perceive color.")
                }
                .font(.body)
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}
