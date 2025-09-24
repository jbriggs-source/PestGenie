import Foundation
import SwiftUI
import AVFoundation
import UIKit

/// QR Code scanner for equipment identification and management
@MainActor
final class QRCodeScannerManager: NSObject, ObservableObject {
    static let shared = QRCodeScannerManager()

    @Published var isScanning = false
    @Published var scanResult: QRScanResult?
    @Published var hasPermission = false
    @Published var permissionDenied = false
    @Published var errorMessage: String?

    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var metadataOutput: AVCaptureMetadataOutput?

    override init() {
        super.init()
        checkPermissions()
    }

    // MARK: - Permission Management

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
            permissionDenied = false
        case .notDetermined:
            requestPermissions()
        case .denied, .restricted:
            hasPermission = false
            permissionDenied = true
        @unknown default:
            hasPermission = false
            permissionDenied = true
        }
    }

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                self?.permissionDenied = !granted
            }
        }
    }

    // MARK: - Scanner Control

    func startScanning() {
        guard hasPermission else {
            checkPermissions()
            return
        }

        guard !isScanning else { return }

        setupCaptureSession()
        isScanning = true
        scanResult = nil
        errorMessage = nil
    }

    func stopScanning() {
        captureSession?.stopRunning()
        isScanning = false
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            errorMessage = "Unable to access camera"
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            errorMessage = "Error creating video input: \(error.localizedDescription)"
            return
        }

        if captureSession?.canAddInput(videoInput) == true {
            captureSession?.addInput(videoInput)
        } else {
            errorMessage = "Unable to add video input"
            return
        }

        metadataOutput = AVCaptureMetadataOutput()

        if captureSession?.canAddOutput(metadataOutput!) == true {
            captureSession?.addOutput(metadataOutput!)

            metadataOutput?.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput?.metadataObjectTypes = [.qr, .code128, .code39, .dataMatrix]
        } else {
            errorMessage = "Unable to add metadata output"
            return
        }

        Task.detached {
            await MainActor.run {
                self.captureSession?.startRunning()
            }
        }
    }

    // MARK: - Preview Layer

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let captureSession = captureSession else { return nil }

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = .resizeAspectFill

        return videoPreviewLayer
    }

    // MARK: - Torch Control

    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }

            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }

    var isTorchOn: Bool {
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        return device.torchMode == .on
    }

    var isTorchAvailable: Bool {
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        return device.hasTorch
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeScannerManager: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

        guard let metadataObject = metadataObjects.first else { return }
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
        guard let stringValue = readableObject.stringValue else { return }

        // Process the scanned code
        let result = QRScanResult(
            code: stringValue,
            type: QRCodeType.fromString(stringValue),
            rawType: readableObject.type.rawValue,
            scannedAt: Date()
        )

        Task { @MainActor in
            self.scanResult = result
            self.stopScanning()

            // Handle deep linking if it's a recognized URL format
            self.handleDeepLinkIfApplicable(result)

            // Post notification for other handlers
            NotificationCenter.default.post(
                name: .qrCodeScanned,
                object: nil,
                userInfo: ["result": result]
            )
        }
    }

    /// Handle deep linking for equipment QR codes
    private func handleDeepLinkIfApplicable(_ result: QRScanResult) {
        let code = result.code

        // Check if it's a deep link URL
        if let url = URL(string: code),
           (url.scheme == "pestgenie" || url.host?.contains("pestgenie") == true) {
            // Use existing deep link manager
            _ = DeepLinkManager.shared.handle(url: url)
            return
        }

        // Check if it's an equipment code that should generate a deep link
        if result.type == .equipment {
            if let equipmentId = parseEquipmentId(from: code) {
                // Generate equipment deep link URL and handle it
                let deepLinkURL = generateEquipmentDeepLink(equipmentId: equipmentId, action: .view)
                if let url = deepLinkURL {
                    _ = DeepLinkManager.shared.handle(url: url)
                }
            }
        }
    }
}

// MARK: - Data Models

/// Represents a QR scan result
struct QRScanResult: Identifiable, Codable, Equatable {
    let id = UUID()
    let code: String
    let type: QRCodeType
    let rawType: String
    let scannedAt: Date

    /// Formatted display string for the code
    var displayCode: String {
        if code.count > 20 {
            return String(code.prefix(17)) + "..."
        }
        return code
    }
}

/// Types of QR codes that can be scanned
enum QRCodeType: String, CaseIterable, Codable {
    case equipment = "equipment"
    case job = "job"
    case chemical = "chemical"
    case unknown = "unknown"

    static func fromString(_ code: String) -> QRCodeType {
        // Parse QR code format to determine type
        let lowercased = code.lowercased()

        if lowercased.hasPrefix("eq-") || lowercased.contains("equipment") {
            return .equipment
        } else if lowercased.hasPrefix("job-") || lowercased.contains("job") {
            return .job
        } else if lowercased.hasPrefix("chem-") || lowercased.contains("chemical") {
            return .chemical
        } else {
            return .unknown
        }
    }

    var title: String {
        switch self {
        case .equipment: return "Equipment"
        case .job: return "Job"
        case .chemical: return "Chemical"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .equipment: return "wrench.and.screwdriver"
        case .job: return "briefcase"
        case .chemical: return "testtube.2"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .equipment: return "blue"
        case .job: return "green"
        case .chemical: return "orange"
        case .unknown: return "gray"
        }
    }
}

// MARK: - SwiftUI Views

/// SwiftUI wrapper for QR code scanner
struct QRCodeScannerView: UIViewRepresentable {
    @ObservedObject var scannerManager: QRCodeScannerManager

    func makeUIView(context: Context) -> QRScannerUIView {
        return QRScannerUIView(scannerManager: scannerManager)
    }

    func updateUIView(_ uiView: QRScannerUIView, context: Context) {
        // Update if needed
    }
}

/// UIKit view for QR scanner
class QRScannerUIView: UIView {
    private let scannerManager: QRCodeScannerManager
    private var previewLayer: AVCaptureVideoPreviewLayer?

    init(scannerManager: QRCodeScannerManager) {
        self.scannerManager = scannerManager
        super.init(frame: .zero)
        setupPreviewLayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPreviewLayer() {
        previewLayer = scannerManager.getPreviewLayer()

        if let previewLayer = previewLayer {
            layer.addSublayer(previewLayer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

/// Complete QR scanner interface with controls
struct QRScannerInterface: View {
    @StateObject private var scannerManager = QRCodeScannerManager.shared
    @State private var showingResult = false
    @Environment(\.dismiss) private var dismiss

    let onScanComplete: (QRScanResult) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if scannerManager.hasPermission {
                    VStack {
                        // Scanner preview
                        QRCodeScannerView(scannerManager: scannerManager)
                            .overlay(
                                ScannerOverlay()
                            )

                        Spacer()

                        // Controls
                        HStack(spacing: 40) {
                            // Cancel button
                            Button(action: {
                                scannerManager.stopScanning()
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }

                            // Torch button
                            if scannerManager.isTorchAvailable {
                                Button(action: {
                                    scannerManager.toggleTorch()
                                }) {
                                    Image(systemName: scannerManager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.bottom, 50)
                    }
                } else if scannerManager.permissionDenied {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("Camera Access Required")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Please enable camera access in Settings to scan QR codes")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Button("Open Settings") {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ProgressView("Requesting camera access...")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .onAppear {
                scannerManager.startScanning()
            }
            .onDisappear {
                scannerManager.stopScanning()
            }
            .onChange(of: scannerManager.scanResult) { _, result in
                if let result = result {
                    onScanComplete(result)
                    showingResult = true
                }
            }
            .alert("QR Code Scanned", isPresented: $showingResult) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let result = scannerManager.scanResult {
                    Text("Scanned \(result.type.title): \(result.displayCode)")
                }
            }
        }
    }
}

/// Scanner overlay with scanning frame
struct ScannerOverlay: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Dark overlay with cutout
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .frame(width: 250, height: 250)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()

            // Scanning frame
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, lineWidth: 3)
                .frame(width: 250, height: 250)

            // Corner indicators
            ForEach(0..<4, id: \.self) { index in
                CornerIndicator()
                    .rotationEffect(.degrees(Double(index) * 90))
                    .frame(width: 250, height: 250)
            }

            // Scanning line animation
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.green, Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 220, height: 2)
                .offset(y: isAnimating ? 100 : -100)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }

            // Instruction text
            VStack {
                Spacer()

                Text("Position QR code within the frame")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
    }
}

/// Corner indicator for scanner overlay
struct CornerIndicator: View {
    var body: some View {
        VStack {
            HStack {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 20, height: 3)
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 3, height: 20)
                Spacer()
            }
            Spacer()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let qrCodeScanned = Notification.Name("qrCodeScanned")
}

// MARK: - Equipment QR Code Helpers

extension QRCodeScannerManager {
    /// Parse equipment ID from QR code
    func parseEquipmentId(from code: String) -> String? {
        // Handle different QR code formats
        let patterns = [
            "eq-([A-Za-z0-9-]+)",          // eq-12345
            "equipment/([A-Za-z0-9-]+)",    // equipment/12345
            "pestgenie://equipment/([A-Za-z0-9-]+)" // deep link format
        ]

        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: code.utf16.count)

            if let match = regex?.firstMatch(in: code, options: [], range: range),
               let idRange = Range(match.range(at: 1), in: code) {
                return String(code[idRange])
            }
        }

        // If no pattern matches, assume the entire code is the ID
        return code
    }

    /// Generate deep link URL for equipment
    func generateEquipmentDeepLink(equipmentId: String, action: DeepLinkManager.DeepLink.EquipmentAction? = nil) -> URL? {
        return DeepLinkManager.shared.generateEquipmentURL(equipmentId: equipmentId, action: action)
    }

    /// Generate QR code for equipment
    func generateEquipmentQRCode(equipmentId: String) -> String {
        if let url = generateEquipmentDeepLink(equipmentId: equipmentId) {
            return url.absoluteString
        } else {
            return "eq-\(equipmentId)"
        }
    }

    /// Validate equipment QR code format
    func isValidEquipmentQRCode(_ code: String) -> Bool {
        return parseEquipmentId(from: code) != nil
    }
}