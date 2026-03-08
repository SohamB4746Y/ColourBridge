import SwiftUI
@preconcurrency import AVFoundation
import CoreImage

// MARK: - CameraManager

@MainActor
final class CameraManager: NSObject, ObservableObject {
    
    // MARK: Authorization
    
    enum AuthStatus {
        case notDetermined, authorized, denied
    }
    
    @Published var authorizationStatus: AuthStatus = .notDetermined
    @Published var currentCIImage: CIImage?
    
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.colorbridge.camera",
                                                qos: .userInitiated)
    private var isConfigured = false
    
    nonisolated(unsafe) private var lastSampleTime: CFAbsoluteTime = 0
    private let minSampleInterval: CFAbsoluteTime = 1.0 / 30.0
    
    /// Shared CIContext used for pixel buffer → CGImage conversion on the camera thread.
    nonisolated(unsafe) private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    // MARK: Setup
    
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
    
    func stopSession() {
        let session = self.session
        processingQueue.async {
            session.stopRunning()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastSampleTime >= minSampleInterval else { return }
        lastSampleTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Convert to CIImage and immediately bake into a CGImage on this thread.
        // CGImage is a plain immutable value — safe to send across actor boundaries.
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        Task { @MainActor [weak self] in
            self?.currentCIImage = CIImage(cgImage: cgImage)
        }
    }
}

// MARK: - CameraAnalyzeView

@MainActor
struct CameraAnalyzeView: View {
    
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentSample: ColorSample?
    @State private var collectedSamples: [ColorSample] = []
    @State private var selectedMode: SimulationMode = .normal
    @State private var tapLocation: CGPoint?
    @State private var showSummary = false
    
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
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
        .onAppear {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(samples: collectedSamples)
        }
    }
    
    // MARK: Camera Content
    
    private var cameraContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                filteredCameraImage
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
                
                if let loc = tapLocation {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .position(loc)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                
                infoCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .ignoresSafeArea()
    }
    
    private var filteredCameraImage: Image {
        guard let rawFrame = cameraManager.currentCIImage else {
            return Image(uiImage: UIImage())
        }
        
        let simulated = ColorAnalyzer.simulateImage(rawFrame, mode: selectedMode)
        
        guard let cgImage = ciContext.createCGImage(simulated, from: simulated.extent) else {
            return Image(uiImage: UIImage())
        }
        
        return Image(uiImage: UIImage(cgImage: cgImage))
    }
    
    // MARK: Info Card
    
    private var displayName: String {
        currentSample?.name ?? "Tap to sample"
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
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
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
        .accessibilityLabel("Color analysis card. Tap anywhere on the camera preview to sample a color. Current sample: \(displayName).")
    }
    
    // MARK: Permission Denied
    
    private var deniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
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
    
    // MARK: Tap Handler
    
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
        
        withAnimation(.easeOut(duration: 0.25)) {
            tapLocation = location
        }
        
        if let sample = ColorAnalyzer.sample(from: ciImage, at: clamped, mode: selectedMode) {
            currentSample = sample
            collectedSamples.append(sample)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { tapLocation = nil }
        }
    }
}

