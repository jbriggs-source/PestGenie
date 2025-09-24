import Foundation
import os.log

/// Monitors app startup performance metrics
final class StartupPerformanceMonitor {
    static let shared = StartupPerformanceMonitor()

    private let logger = Logger(subsystem: "com.pestgenie.app", category: "performance")
    private var startTime: CFAbsoluteTime = 0
    private var checkpoints: [(name: String, time: CFAbsoluteTime)] = []

    private init() {
        startTime = CFAbsoluteTimeGetCurrent()
    }

    /// Mark the app launch start time
    func markAppLaunchStart() {
        startTime = CFAbsoluteTimeGetCurrent()
        logger.info("🚀 App launch started")
    }

    /// Mark a checkpoint during startup
    func markCheckpoint(_ name: String) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsed = currentTime - startTime
        checkpoints.append((name: name, time: currentTime))

        logger.info("✓ \(name) - \(String(format: "%.2f", elapsed * 1000))ms")

        #if DEBUG
        print("⏱ Startup checkpoint: \(name) - \(String(format: "%.2f", elapsed * 1000))ms")
        #endif
    }

    /// Mark when the app is fully ready
    func markAppReady() {
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("✅ App fully loaded - Total: \(String(format: "%.2f", totalTime * 1000))ms")

        #if DEBUG
        print("\n📊 Startup Performance Summary:")
        print("================================")
        var lastTime = startTime
        for checkpoint in checkpoints {
            let duration = (checkpoint.time - lastTime) * 1000
            print("• \(checkpoint.name): \(String(format: "%.2f", duration))ms")
            lastTime = checkpoint.time
        }
        print("--------------------------------")
        print("Total startup time: \(String(format: "%.2f", totalTime * 1000))ms")
        print("================================\n")
        #endif

        // In production, you might send these metrics to analytics
        reportMetrics(totalTime: totalTime)
    }

    private func reportMetrics(totalTime: CFAbsoluteTime) {
        // Report to analytics service
        let metrics: [String: Any] = [
            "startup_time_ms": totalTime * 1000,
            "checkpoint_count": checkpoints.count
        ]

        // In production, send to analytics
        #if DEBUG
        logger.debug("Metrics ready for reporting: \(metrics)")
        #endif
    }

    /// Get current startup time (for debugging)
    func getCurrentStartupTime() -> Double {
        return (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    }
}