import SwiftUI
import Charts

/// Presents aggregated readability metrics for sampled colors.
@MainActor
struct SummaryView: View {

    /// Collected samples from camera or static-image workflows.
    let samples: [ColorSample]
    @Environment(\.dismiss) private var dismiss

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

    /// Main summary layout containing chart, explanation, and restart action.
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                chartSection

                explanationSection

                Button {
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
    }

    /// Bar chart section visualizing readability distribution.
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Readability Overview")
                .font(.title3.bold())
                .padding(.horizontal)

            Chart(chartData) { bucket in
                BarMark(
                    x: .value("Category", bucket.category),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(bucket.category == "Readable" ? Color.green : Color.red)
                .cornerRadius(6)
                .annotation(position: .top) {
                    Text("\(bucket.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("\(bucket.category), \(bucket.count) taps")
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
            .padding(.horizontal)
        }
    }

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
                        Text("All sampled colors met at least a 4.5 : 1 contrast ratio — great for readability!")
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

/// Lightweight chart model representing one readability category bucket.
private struct ReadabilityBucket: Identifiable, Sendable {
    let category: String
    let count: Int
    var id: String { category }
}
