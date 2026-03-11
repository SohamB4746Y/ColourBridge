// MARK: - Root Navigation

import SwiftUI
import PhotosUI
import CoreImage

// MARK: - ContentView

/// Root navigation container for the application.
@MainActor
struct ContentView: View {

    // MARK: Body

    /// Declares the root navigation stack.
    var body: some View {
        NavigationStack {
            WelcomeView()
        }
    }
}

// MARK: - WelcomeView

/// Landing experience that routes users to camera, sample, or photo workflows.
@MainActor
struct WelcomeView: View {

    // MARK: State

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var loadedCIImage: CIImage?
    @State private var isNavigatingToPhoto = false
    @State private var isLoadingPhoto = false
    @State private var headerVisible = false
    @State private var buttonsVisible = false

    // MARK: Body

    /// Primary welcome interface and top-level actions.
    var body: some View {
        ScrollView {
            VStack(spacing: AppConstants.welcomeSectionSpacing) {
                // MARK: Header
                VStack(spacing: 12) {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    Text("ColorBridge")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text("Understand color‑coded information through the lens of color‑vision accessibility.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 20)

                // MARK: Preview
                colorPreview

                // MARK: Actions
                VStack(spacing: AppConstants.welcomeButtonSpacing) {
                    NavigationLink {
                        CameraAnalyzeView()
                    } label: {
                        Label("Start with Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint("Opens the live camera to analyze colors in your surroundings.")

                    NavigationLink {
                        SampleAnalyzeView()
                    } label: {
                        Label("Try Sample Chart", systemImage: "chart.bar.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.secondary)
                    .accessibilityHint("Opens a built‑in sample chart to preview color analysis.")

                    if isLoadingPhoto {
                        ProgressView("Loading photo…")
                            .frame(maxWidth: .infinity)
                            .controlSize(.regular)
                    } else {
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.indigo)
                        .accessibilityHint("Pick a photo from your library to analyze its colors.")
                    }
                }
                .padding(.horizontal)

                // MARK: Privacy Notice
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.tertiary)
                        .font(.footnote)
                        .accessibilityHidden(true)
                    Text("All processing stays on your device. No photos are stored or uploaded.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, AppConstants.welcomeVerticalPadding)
        }
        .navigationTitle("ColorBridge")
        .toolbar(.hidden, for: .navigationBar)
        .task {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                headerVisible = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                buttonsVisible = true
            }
        }
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            isLoadingPhoto = true
            Task { @MainActor in
                defer {
                    isLoadingPhoto = false
                    selectedPhoto = nil
                }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data),
                   let cgImage = uiImage.cgImage {
                    let exifOrientation: CGImagePropertyOrientation = switch uiImage.imageOrientation {
                    case .up:            .up
                    case .down:          .down
                    case .left:          .left
                    case .right:         .right
                    case .upMirrored:    .upMirrored
                    case .downMirrored:  .downMirrored
                    case .leftMirrored:  .leftMirrored
                    case .rightMirrored: .rightMirrored
                    @unknown default:    .up
                    }
                    let ciImage = CIImage(cgImage: cgImage).oriented(exifOrientation)
                    loadedCIImage = ciImage
                    isNavigatingToPhoto = true
                }
            }
        }
        .navigationDestination(isPresented: $isNavigatingToPhoto) {
            if let ciImage = loadedCIImage {
                SampleAnalyzeView(externalImage: ciImage)
            }
        }
    }

    // MARK: Color Preview

    /// Preview strip illustrating standard versus accessibility-enhanced presentation.
    private var colorPreview: some View {
        HStack(spacing: 16) {
            previewCard(title: "Original", colors: [.red, .green])
            previewCard(title: "Accessible", colors: [.red, .green], accessible: true)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview showing an original color pair and its accessible alternative with patterns.")
    }

    // MARK: Preview Card

    /// Builds a compact preview card used in the landing comparison row.
    ///
    /// - Parameters:
    ///   - title: Card title text.
    ///   - colors: Colors rendered as preview swatches.
    ///   - accessible: Indicates whether symbolic overlays should be shown.
    /// - Returns: A configured preview card view.
    private func previewCard(title: String, colors: [Color], accessible: Bool = false) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(accessible ? 0.85 : 0.65))
                        .frame(height: 60)
                        .overlay {
                            if accessible {
                                Image(systemName: index == 0 ? "line.diagonal" : "circle.grid.2x2.fill")
                                    .foregroundStyle(.white.opacity(0.7))
                                    .font(.title3)
                            }
                        }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
