import Foundation
import os.log

/// Comprehensive error handling and reporting system for enterprise applications
@MainActor
final class ErrorManager: ObservableObject {
    static let shared = ErrorManager()

    @Published var currentError: PestGenieError?
    @Published var errorHistory: [ErrorReport] = []

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PestGenie", category: "ErrorManager")
    private let maxErrorHistory = 50

    private init() {}

    // MARK: - Public Interface

    /// Report an error with comprehensive context
    func reportError(
        _ error: Error,
        context: ErrorContext,
        severity: ErrorSeverity = .medium,
        userMessage: String? = nil,
        retryable: Bool = false
    ) {
        let pestGenieError = PestGenieError(
            originalError: error,
            context: context,
            severity: severity,
            userMessage: userMessage,
            retryable: retryable,
            timestamp: Date()
        )

        handleError(pestGenieError)
    }

    /// Handle a PestGenieError with appropriate actions
    private func handleError(_ error: PestGenieError) {
        // Log the error
        logError(error)

        // Add to history
        addToHistory(error)

        // Set current error for UI display if appropriate
        if error.severity >= .medium {
            currentError = error
        }

        // Report to analytics in production
        #if !DEBUG
        reportToAnalytics(error)
        #endif

        // Schedule retry if applicable
        if error.retryable {
            scheduleRetry(for: error)
        }

        // Send crash report for critical errors
        if error.severity == .critical {
            sendCrashReport(error)
        }
    }

    /// Clear the current error (when user dismisses)
    func clearCurrentError() {
        currentError = nil
    }

    /// Get filtered error history
    func getErrorHistory(
        severity: ErrorSeverity? = nil,
        context: ErrorContext? = nil,
        since: Date? = nil
    ) -> [ErrorReport] {
        return errorHistory.filter { report in
            if let severity = severity, report.error.severity != severity { return false }
            if let context = context, report.error.context != context { return false }
            if let since = since, report.error.timestamp < since { return false }
            return true
        }
    }

    // MARK: - Private Methods

    private func logError(_ error: PestGenieError) {
        let logLevel: OSLogType = switch error.severity {
        case .low: .info
        case .medium: .error
        case .high: .error
        case .critical: .fault
        }

        logger.log(level: logLevel, """
        Error occurred in \(error.context.rawValue, privacy: .public)
        Type: \(String(describing: type(of: error.originalError)), privacy: .public)
        Message: \(error.originalError.localizedDescription, privacy: .public)
        Retryable: \(error.retryable ? "Yes" : "No", privacy: .public)
        """)
    }

    private func addToHistory(_ error: PestGenieError) {
        let report = ErrorReport(
            id: UUID(),
            error: error,
            reportedAt: Date()
        )

        errorHistory.insert(report, at: 0)

        // Maintain maximum history size
        if errorHistory.count > maxErrorHistory {
            errorHistory = Array(errorHistory.prefix(maxErrorHistory))
        }
    }

    private func reportToAnalytics(_ error: PestGenieError) {
        // Integration point for analytics services
        ErrorAnalyticsManager.shared.recordError(error)
    }

    private func scheduleRetry(for error: PestGenieError) {
        guard error.retryable else { return }

        Task {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

            // Attempt retry based on context
            switch error.context {
            case .sync:
                try? await SyncManager.shared.syncNow()
            case .weather:
                // Retry weather fetch
                break
            case .network:
                // Retry network operation
                break
            default:
                break
            }
        }
    }

    private func sendCrashReport(_ error: PestGenieError) {
        #if !DEBUG
        CrashReportingService.shared.recordCriticalError(error)
        #endif
    }
}

// MARK: - Error Types

/// Comprehensive error type for the PestGenie application
struct PestGenieError {
    let id = UUID()
    let originalError: Error
    let context: ErrorContext
    let severity: ErrorSeverity
    let userMessage: String?
    let retryable: Bool
    let timestamp: Date

    /// User-friendly error message
    var displayMessage: String {
        if let userMessage = userMessage {
            return userMessage
        }

        // Generate contextual message based on error type
        switch context {
        case .sync:
            return "Failed to sync data. Please check your internet connection."
        case .weather:
            return "Unable to fetch weather data. Using cached information."
        case .database:
            return "Database operation failed. Your data is safe."
        case .network:
            return "Network connection issue. Please try again."
        case .authentication:
            return "Authentication failed. Please log in again."
        case .validation:
            return "Please check your input and try again."
        case .fileSystem:
            return "File operation failed. Please try again."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
}

enum ErrorContext: String, CaseIterable {
    case sync = "sync"
    case weather = "weather"
    case database = "database"
    case network = "network"
    case authentication = "authentication"
    case validation = "validation"
    case fileSystem = "file_system"
    case unknown = "unknown"
}

enum ErrorSeverity: Int, Comparable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .low: return "Info"
        case .medium: return "Warning"
        case .high: return "Error"
        case .critical: return "Critical"
        }
    }
}

/// Error report for history tracking
struct ErrorReport: Identifiable {
    let id: UUID
    let error: PestGenieError
    let reportedAt: Date
}

// MARK: - Error Analytics Manager (Placeholder)

final class ErrorAnalyticsManager {
    static let shared = ErrorAnalyticsManager()

    private init() {}

    func recordError(_ error: PestGenieError) {
        // Integration point for analytics services like Firebase Analytics
        print("📊 Recording error for analytics: \(error.context.rawValue)")
    }
}

// MARK: - Crash Reporting Service (Placeholder)

final class CrashReportingService {
    static let shared = CrashReportingService()

    private init() {}

    func recordCriticalError(_ error: PestGenieError) {
        // Integration point for crash reporting services like Crashlytics
        print("💥 Recording critical error: \(error.originalError.localizedDescription)")
    }
}

// MARK: - Error Extensions

extension Error {
    /// Check if error is retryable based on its type
    var isRetryable: Bool {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost:
                return true
            default:
                return false
            }
        }

        // Add other retryable error types here
        return false
    }

    /// Get appropriate error context based on error type
    var context: ErrorContext {
        if self is URLError {
            return .network
        }

        // Add other error type mappings here
        return .unknown
    }
}

// MARK: - Usage Examples and Patterns

extension ErrorManager {
    /// Convenience method for network errors
    func reportNetworkError(_ error: Error, operation: String) {
        reportError(
            error,
            context: .network,
            severity: error.isRetryable ? .medium : .high,
            userMessage: "Network operation '\(operation)' failed. Please check your connection.",
            retryable: error.isRetryable
        )
    }

    /// Convenience method for sync errors
    func reportSyncError(_ error: Error) {
        reportError(
            error,
            context: .sync,
            severity: .medium,
            userMessage: "Data synchronization failed. Your changes are saved locally.",
            retryable: true
        )
    }

    /// Convenience method for validation errors
    func reportValidationError(_ message: String) {
        struct ValidationError: Error, LocalizedError {
            let errorDescription: String?
            init(message: String) {
                self.errorDescription = message
            }
        }

        reportError(
            ValidationError(message: message),
            context: .validation,
            severity: .low,
            userMessage: message,
            retryable: false
        )
    }
}