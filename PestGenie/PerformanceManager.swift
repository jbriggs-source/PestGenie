import Foundation
import SwiftUI
import Combine
import os.log

/// Manages app performance monitoring, optimization, and diagnostics
@MainActor
final class PerformanceManager: ObservableObject {
    static let shared = PerformanceManager()

    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    @Published var isMonitoring = false

    private var metricsTimer: Timer?
    private let logger = Logger(subsystem: "com.pestgenie.performance", category: "metrics")

    // Memory pressure monitoring
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    init() {
        setupMemoryPressureMonitoring()
    }

    // MARK: - Performance Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        logger.info("Started performance monitoring")

        // Update metrics every 30 seconds
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                self.updateMetrics()
            }
        }

        updateMetrics()
    }

    func stopMonitoring() {
        isMonitoring = false
        metricsTimer?.invalidate()
        metricsTimer = nil
        logger.info("Stopped performance monitoring")
    }

    private func updateMetrics() {
        let usage = getMemoryUsage()
        let energy = getEnergyImpact()
        let disk = getDiskUsage()
        let network = getNetworkUsage()

        metrics = PerformanceMetrics(
            memoryUsage: usage.used,
            memoryPressure: usage.pressure,
            energyImpact: energy,
            diskUsage: disk,
            networkBytesIn: network.bytesIn,
            networkBytesOut: network.bytesOut,
            timestamp: Date()
        )

        // Log critical metrics
        if usage.pressure > 0.8 {
            logger.warning("High memory pressure: \(usage.pressure, privacy: .public)")
        }

        if energy > 0.7 {
            logger.warning("High energy impact: \(energy, privacy: .public)")
        }
    }

    // MARK: - Memory Management

    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.main
        )

        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }

        memoryPressureSource?.resume()
    }

    private func handleMemoryPressure() async {
        logger.warning("Memory pressure detected - triggering cleanup")

        // Clear image caches
        ImageCacheManager.shared.clearCache()

        // Clear SDUI component cache
        SDUIComponentCache.shared.clearCache()

        // Force garbage collection
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                // Perform memory cleanup operations
                autoreleasepool {
                    // Memory cleanup work
                }
                continuation.resume()
            }
        }

        // Post notification for other components to clean up
        NotificationCenter.default.post(name: .memoryPressureDetected, object: nil)
    }

    private func getMemoryUsage() -> (used: Double, pressure: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let usedMemoryMB = result == KERN_SUCCESS ? Double(info.resident_size) / 1024 / 1024 : 0

        // Calculate pressure based on available memory
        let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        let pressure = usedMemoryMB / physicalMemory

        return (usedMemoryMB, pressure)
    }

    private func getEnergyImpact() -> Double {
        // Simplified energy impact calculation
        // In production, use more sophisticated metrics
        let cpuUsage = getCPUUsage()
        let networkActivity = metrics.networkBytesIn + metrics.networkBytesOut
        let normalizedNetwork = min(networkActivity / 1_000_000, 1.0) // Normalize to MB

        return (cpuUsage * 0.6) + (normalizedNetwork * 0.4)
    }

    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Double(info.policy) / 100.0 : 0
    }

    private func getDiskUsage() -> Double {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return 0
        }

        do {
            let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])

            if let available = resourceValues.volumeAvailableCapacity,
               let total = resourceValues.volumeTotalCapacity {
                return Double(total - available) / Double(total)
            }
        } catch {
            logger.error("Failed to get disk usage: \(error.localizedDescription)")
        }

        return 0
    }

    private func getNetworkUsage() -> (bytesIn: Double, bytesOut: Double) {
        // This is a simplified implementation
        // In production, use more sophisticated network monitoring
        return (0, 0)
    }

    deinit {
        memoryPressureSource?.cancel()
    }
}

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let memoryUsage: Double
    let memoryPressure: Double
    let energyImpact: Double
    let diskUsage: Double
    let networkBytesIn: Double
    let networkBytesOut: Double
    let timestamp: Date

    init(
        memoryUsage: Double = 0,
        memoryPressure: Double = 0,
        energyImpact: Double = 0,
        diskUsage: Double = 0,
        networkBytesIn: Double = 0,
        networkBytesOut: Double = 0,
        timestamp: Date = Date()
    ) {
        self.memoryUsage = memoryUsage
        self.memoryPressure = memoryPressure
        self.energyImpact = energyImpact
        self.diskUsage = diskUsage
        self.networkBytesIn = networkBytesIn
        self.networkBytesOut = networkBytesOut
        self.timestamp = timestamp
    }

    var memoryUsageFormatted: String {
        String(format: "%.1f MB", memoryUsage)
    }

    var memoryPressureFormatted: String {
        String(format: "%.1f%%", memoryPressure * 100)
    }

    var energyImpactFormatted: String {
        let level: String
        if energyImpact < 0.3 {
            level = "Low"
        } else if energyImpact < 0.7 {
            level = "Medium"
        } else {
            level = "High"
        }
        return level
    }

    var diskUsageFormatted: String {
        String(format: "%.1f%%", diskUsage * 100)
    }
}

// MARK: - Image Cache Manager

@MainActor
final class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()

    private var cache: [String: UIImage] = [:]
    private var accessTimes: [String: Date] = [:]
    private let maxCacheSize = 50 // Maximum number of images
    private let maxAge: TimeInterval = 300 // 5 minutes

    private init() {
        setupCleanupTimer()
    }

    func cacheImage(_ image: UIImage, forKey key: String) {
        // Remove old images if cache is full
        if cache.count >= maxCacheSize {
            removeOldestImage()
        }

        cache[key] = image
        accessTimes[key] = Date()
    }

    func getImage(forKey key: String) -> UIImage? {
        if let image = cache[key] {
            accessTimes[key] = Date() // Update access time
            return image
        }
        return nil
    }

    func clearCache() {
        cache.removeAll()
        accessTimes.removeAll()
    }

    private func setupCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                self.cleanupExpiredImages()
            }
        }
    }

    private func cleanupExpiredImages() {
        let now = Date()
        let expiredKeys = accessTimes.compactMap { key, time in
            now.timeIntervalSince(time) > maxAge ? key : nil
        }

        for key in expiredKeys {
            cache.removeValue(forKey: key)
            accessTimes.removeValue(forKey: key)
        }
    }

    private func removeOldestImage() {
        guard let oldestKey = accessTimes.min(by: { $0.value < $1.value })?.key else { return }
        cache.removeValue(forKey: oldestKey)
        accessTimes.removeValue(forKey: oldestKey)
    }
}

// MARK: - SDUI Component Cache

@MainActor
final class SDUIComponentCache: ObservableObject {
    static let shared = SDUIComponentCache()

    private var viewCache: [String: AnyView] = [:]
    private var accessTimes: [String: Date] = [:]
    private let maxCacheSize = 100
    private let maxAge: TimeInterval = 600 // 10 minutes

    private init() {
        setupCleanupTimer()
    }

    func cacheView<T: View>(_ view: T, forKey key: String) {
        if viewCache.count >= maxCacheSize {
            removeOldestView()
        }

        viewCache[key] = AnyView(view)
        accessTimes[key] = Date()
    }

    func getView(forKey key: String) -> AnyView? {
        if let view = viewCache[key] {
            accessTimes[key] = Date()
            return view
        }
        return nil
    }

    func clearCache() {
        viewCache.removeAll()
        accessTimes.removeAll()
    }

    private func setupCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { _ in
            Task { @MainActor in
                self.cleanupExpiredViews()
            }
        }
    }

    private func cleanupExpiredViews() {
        let now = Date()
        let expiredKeys = accessTimes.compactMap { key, time in
            now.timeIntervalSince(time) > maxAge ? key : nil
        }

        for key in expiredKeys {
            viewCache.removeValue(forKey: key)
            accessTimes.removeValue(forKey: key)
        }
    }

    private func removeOldestView() {
        guard let oldestKey = accessTimes.min(by: { $0.value < $1.value })?.key else { return }
        viewCache.removeValue(forKey: oldestKey)
        accessTimes.removeValue(forKey: oldestKey)
    }
}

// MARK: - Lazy Loading Components

struct LazySDUIRenderer: View {
    let component: SDUIComponent
    let context: SDUIContext

    @State private var isLoaded = false

    var body: some View {
        Group {
            if isLoaded {
                SDUIScreenRenderer.render(component: component, context: context)
            } else {
                ProgressView()
                    .onAppear {
                        // Delay loading to prevent blocking main thread
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isLoaded = true
                        }
                    }
            }
        }
    }
}

// MARK: - Battery Optimization

struct BatteryOptimizedView<Content: View>: View {
    let content: Content

    @StateObject private var performanceManager = PerformanceManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .memoryPressureDetected)) { _ in
                // Reduce animation complexity during memory pressure
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .background:
                    performanceManager.stopMonitoring()
                case .active:
                    performanceManager.startMonitoring()
                default:
                    break
                }
            }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let memoryPressureDetected = Notification.Name("memoryPressureDetected")
}

// MARK: - View Extensions

extension View {
    func optimizeForBattery() -> some View {
        BatteryOptimizedView {
            self
        }
    }
}