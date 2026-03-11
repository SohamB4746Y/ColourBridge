// MARK: - Camera Analysis

import SwiftUI
@preconcurrency import AVFoundation
import CoreImage

// MARK: - CameraManager

/// Manages camera permissions, session lifecycle, and frame delivery.
@MainActor
final class CameraManager: NSObject, ObservableObject {

    // MARK: Types

    /// Camera permission state used by the UI to present the correct screen.
    enum AuthStatus {
        case notDetermined, authorized, denied
    }

    // MARK: Published State

    @Published var authorizationStatus: AuthStatus = .notDetermined
    @Published var currentCIImage: CIImage?

    // MARK: Private Properties

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.colorbridge.camera",
                                                qos: .userInitiated)
    private var isConfigured = false

    nonisolated(unsafe) private var lastSampleTime: CFAbsoluteTime = 0
    private let minSampleInterval: CFAbsoluteTime = AppConstants.cameraFrameInterval

    /// Shared Core Image context — reused across all frame renders.
    nonisolated(unsafe) private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: Lifecycle

    deinit {
        session.stopRunning()
    }

    // MARK: Authorization

    /// Requests or refreshes camera authorization status.
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.authorizationStatus = granted ? .authorized : .denied
                }
            }
        default:
            authorizationStatus = .denied
        }
    }

    // MARK: Session Control

    /// Starts camera capture, configuring the session once when required.
    func startSession() {
        let session = self.session
        let videoOutput = self.videoOutput
        let needsConfigure = !isConfigured
        isConfigured = true

        processingQueue.async { [weak self] in
            if needsConfigure {
                self?.configureSession(session: session, videoOutput: videoOutput)
            }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    /// Stops camera capture asynchronously.
    func stopSession() {
        let session = self.session
        processingQueue.async {
            session.stopRunning()
        }
    }

    // MARK: Session Configuration

    /// Configures camera input and video output for capture callbacks.
    nonisolated private func configureSession(session: AVCaptureSession,
                                              videoOutput: AVCaptureVideoDataOutput) {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let delegateQueue = DispatchQueue(label: "com.colorbridge.camera.delegate",
                                          qos: .userInitiated)
        videoOutput.setSampleBufferDelegate(self, queue: delegateQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
        }

        session.commitConfiguration()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Delivers throttled camera frames converted to `CIImage` for UI analysis.
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastSampleTime >= minSampleInterval else { return }
        lastSampleTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        Task { @MainActor [weak self] in
            self?.currentCIImage = CIImage(cgImage: cgImage)
        }
    }
}

// MARK: - CameraAnalyzeView

/// Live camera analysis screen with tap-to-sample interaction.
@MainActor
struct CameraAnalyzeView: View {

    // MARK: State

    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss

    @State private var currentSample: ColorSample?
    @State private var collectedSamples: [ColorSample] = []
    @State private var selectedMode: SimulationMode = .normal
    @State private var tapLocation: CGPoint?
    @State private var showSummary = false
    @State private var cachedDisplayImage: UIImage?

    // MARK: Body

    /// Main camera state routing based on permission and session status.
    var body: some View {
        Group {
            switch cameraManager.authorizationStatus {
            case .notDetermined:
                ProgressView("Requesting camera access…")
            case .denied:
                deniedView
            case .authorized:
                cameraContent
            }
        }
        .task {
            cameraManager.checkAuthorization()
            if cameraManager.authorizationStatus == .authorized {
                cameraManager.startSession()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: cameraManager.authorizationStatus) {
            if cameraManager.authorizationStatus == .authorized {
                cameraManager.startSession()
            }
        }
        .onChange(of: cameraManager.currentCIImage) {
            updateDisplayImage()
        }
        .onChange(of: selectedMode) {
            updateDisplayImage()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(samples: collectedSamples)
        }
    }

    // MARK: Camera Content

    /// Camera preview layer with tap gesture sampling and floating analysis card.
    private var cameraContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                displayImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .contentShape(Rectangle())
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onTapGesture { location in
                        handleTap(at: location, in: geo.size)
                    }
                    .accessibilityLabel("Camera preview")
                    .accessibilityHint("Tap anywhere to sample the color at that point.")

                if collectedSamples.isEmpty {
                    instructionBanner
                }

                if let loc = tapLocation {
                    TapIndicatorView(position: loc, lineWidth: 2)
                }

                AnalysisInfoCard(
                    currentSample: currentSample,
                    collectedSamples: collectedSamples,
                    selectedMode: $selectedMode,
                    showSummary: $showSummary,
                    emptyLabel: "Tap to sample"
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Cached Display Image

    /// The current preview image (updated via `onChange`).
    private var displayImage: Image {
        if let uiImage = cachedDisplayImage {
            return Image(uiImage: uiImage)
        }
        return Image(uiImage: UIImage())
    }

    /// Rebuilds the display image from the latest camera frame and simulation mode.
    /// Called via `onChange` so the heavy CIContext work runs once per frame/mode change.
    private func updateDisplayImage() {
        guard let rawFrame = cameraManager.currentCIImage else { return }
        let simulated = ColorAnalyzer.simulateImage(rawFrame, mode: selectedMode)
        guard let cgImage = ColorAnalyzer.sharedContext.createCGImage(
            simulated, from: simulated.extent
        ) else { return }
        cachedDisplayImage = UIImage(cgImage: cgImage)
    }

    // MARK: Instruction Banner

    /// First-time instruction banner shown before any samples are taken.
    private var instructionBanner: some View {
        VStack {
            Text("Tap anywhere on the preview to sample a color")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(.top, 60)

            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: Denied View

    /// User guidance screen displayed when camera permission is denied.
    private var deniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Camera Access Denied")
                .font(.title2.bold())

            Text("ColorBridge needs camera access to analyze colors in real time. You can enable it in Settings → Privacy → Camera.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Go Back") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Camera")
    }

    // MARK: Tap Handling

    /// Maps tap coordinates from view space into image space and records a sample.
    ///
    /// - Parameters:
    ///   - location: Tap location in view coordinates.
    ///   - viewSize: Size of the rendered preview region.
    private func handleTap(at location: CGPoint, in viewSize: CGSize) {
        guard let ciImage = cameraManager.currentCIImage else { return }

        let imageSize = ciImage.extent.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect  = viewSize.width  / viewSize.height

        let drawnRect: CGRect
        if imageAspect > viewAspect {
            let drawnHeight = viewSize.height
            let drawnWidth  = drawnHeight * imageAspect
            let originX     = (viewSize.width - drawnWidth) / 2.0
            drawnRect = CGRect(x: originX, y: 0, width: drawnWidth, height: drawnHeight)
        } else {
            let drawnWidth  = viewSize.width
            let drawnHeight = drawnWidth / imageAspect
            let originY     = (viewSize.height - drawnHeight) / 2.0
            drawnRect = CGRect(x: 0, y: originY, width: drawnWidth, height: drawnHeight)
        }

        let relativeX = location.x - drawnRect.origin.x
        let relativeY = location.y - drawnRect.origin.y

        let scaleX = imageSize.width  / drawnRect.width
        let scaleY = imageSize.height / drawnRect.height
        let pixelX = relativeX * scaleX
        let pixelY = relativeY * scaleY

        let flippedPixelY = imageSize.height - pixelY

        let normalized = CGPoint(
            x: pixelX / imageSize.width,
            y: flippedPixelY / imageSize.height
        )

        let clamped = CGPoint(
            x: min(max(normalized.x, 0), 1),
            y: min(max(normalized.y, 0), 1)
        )

        withAnimation(.easeOut(duration: AppConstants.tapAnimationDuration)) {
            tapLocation = location
        }

        if let sample = ColorAnalyzer.sample(from: ciImage, at: clamped, mode: selectedMode) {
            currentSample = sample
            collectedSamples.append(sample)
            HapticEngine.sampleTap()
        }
            try? await Task.sleep(for: .seconds(AppConstants.tapIndicatorDismissDelay))
            withAnimation { tapLocation = nil }
        }
    }
}
