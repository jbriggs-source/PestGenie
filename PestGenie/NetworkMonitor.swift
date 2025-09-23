import Foundation
import Network
import Combine
import UIKit

/// Enhanced network monitoring for offline-first architecture
/// Provides detailed connection information and automatic sync triggers
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .none
    @Published var isExpensive = false
    @Published var isConstrained = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    enum ConnectionType: String, CaseIterable {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case other = "Other"
        case none = "None"

        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "cable.connector"
            case .other: return "network"
            case .none: return "wifi.slash"
            }
        }
    }

    private init() {
        startMonitoring()
    }

    deinit {
        // Stop monitoring synchronously to avoid capturing self in async context
        monitor.cancel()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }

                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained

                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else if path.status == .satisfied {
                    self.connectionType = .other
                } else {
                    self.connectionType = .none
                }

                // Trigger sync when connection is restored
                if !wasConnected && self.isConnected {
                    await self.handleConnectionRestored()
                }

                // Post notification for other components
                NotificationCenter.default.post(name: .networkStatusChanged, object: nil)
            }
        }

        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }

    private func handleConnectionRestored() async {
        print("Network connection restored. Triggering sync...")
        await SyncManager.shared.syncNow()
    }

    /// Returns true if the current connection is suitable for large uploads
    var isSuitableForLargeUploads: Bool {
        return isConnected && !isExpensive && !isConstrained && connectionType == .wifi
    }

    /// Returns true if the current connection is suitable for essential sync only
    var shouldLimitDataUsage: Bool {
        return isExpensive || isConstrained || connectionType == .cellular
    }
}

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

/// API service with offline support and automatic retry logic
final class APIService {
    static let shared = APIService()

    private let baseURL = URL(string: "https://api.pestgenie.com/v1")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.networkServiceType = .default
        self.session = URLSession(configuration: config)
    }

    // MARK: - Job Operations

    func uploadJob(_ job: JobUploadData) async throws -> UploadResponse {
        let url = baseURL.appendingPathComponent("jobs")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(job)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse
    }

    func uploadPhoto(_ imageData: Data, for jobId: String) async throws -> PhotoUploadResponse {
        let url = baseURL.appendingPathComponent("jobs/\(jobId)/photos")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        let photoResponse = try JSONDecoder().decode(PhotoUploadResponse.self, from: data)
        return photoResponse
    }

    func getUpdates(since date: Date) async throws -> ServerUpdates {
        var components = URLComponents(url: baseURL.appendingPathComponent("updates"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: date))
        ]

        let request = URLRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let updates = try decoder.decode(ServerUpdates.self, from: data)
        return updates
    }

    // MARK: - Chemical Operations
    
    func uploadChemical(_ chemical: ChemicalUploadData) async throws -> UploadResponse {
        let url = baseURL.appendingPathComponent("chemicals")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(chemical)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse
    }
    
    func uploadChemicalTreatment(_ treatment: ChemicalTreatmentUploadData) async throws -> UploadResponse {
        let url = baseURL.appendingPathComponent("chemical-treatments")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(treatment)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse
    }

    // MARK: - Push Notification Registration

    func registerDeviceToken(_ token: Data) async throws {
        let url = baseURL.appendingPathComponent("devices/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let registrationData = DeviceRegistration(
            token: token.map { String(format: "%02.2hhx", $0) }.joined(),
            platform: "ios",
            bundleId: Bundle.main.bundleIdentifier ?? ""
        )

        request.httpBody = try JSONEncoder().encode(registrationData)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}

// MARK: - API Error Types

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case networkUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkUnavailable:
            return "Network unavailable"
        case .timeout:
            return "Request timeout"
        }
    }
}

// MARK: - Supporting Types

struct DeviceRegistration: Codable {
    let token: String
    let platform: String
    let bundleId: String
}

/// Image compression service for efficient photo uploads
actor ImageCompressionService {
    static func compress(_ imageData: Data, quality: CGFloat = 0.7) async -> Data {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = UIImage(data: imageData) else {
                    continuation.resume(returning: imageData)
                    return
                }

                // Resize if too large
                let maxSize: CGFloat = 1920
                let resizedImage: UIImage

                if max(image.size.width, image.size.height) > maxSize {
                    let scale = maxSize / max(image.size.width, image.size.height)
                    let newSize = CGSize(
                        width: image.size.width * scale,
                        height: image.size.height * scale
                    )
                    resizedImage = image.resized(to: newSize)
                } else {
                    resizedImage = image
                }

                let compressedData = resizedImage.jpegData(compressionQuality: quality) ?? imageData
                continuation.resume(returning: compressedData)
            }
        }
    }
}

// MARK: - Response Types
// Note: Response types are defined in SyncManager.swift

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}