import Foundation
import HealthKit
import CoreMotion
import Combine
import SwiftUI

/// Comprehensive HealthKit Manager for tracking technician activity during property inspections
@MainActor
final class HealthKitManager: ObservableObject {

    // MARK: - Singleton Instance
    static let shared = HealthKitManager()

    // MARK: - HealthKit Store
    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    // MARK: - Published Properties
    @Published var isHealthKitAvailable: Bool = false
    @Published var isAuthorized: Bool = false
    @Published var isTrackingEnabled: Bool = true
    @Published var privacySettings = HealthPrivacySettings()

    // MARK: - Real-time Activity Data
    @Published var currentStepCount: Int = 0
    @Published var currentDistance: Double = 0.0 // in meters
    @Published var currentActiveCalories: Double = 0.0
    @Published var isActivelyWalking: Bool = false

    // MARK: - Job-specific Activity Tracking
    @Published var activeJobSession: JobHealthSession?
    @Published var todaysTotalSteps: Int = 0
    @Published var todaysTotalDistance: Double = 0.0
    @Published var todaysTotalActiveTime: TimeInterval = 0

    // MARK: - Activity Summary for Dashboard
    @Published var currentActivitySummary: ActivitySummary = ActivitySummary(
        currentSteps: 0,
        currentDistance: 0.0,
        isActivelyWalking: false,
        sessionSteps: 0,
        sessionDistance: 0.0,
        sessionDuration: 0,
        todaySteps: 0,
        todayDistance: 0.0,
        weeklyAverage: 0
    )

    // MARK: - Weekly Statistics
    @Published var weeklyStepsData: [DailyStepsData] = []
    @Published var weeklyDistanceData: [DailyDistanceData] = []

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var stepCountingTimer: Timer?
    private var pedometerUpdates: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Health Data Types
    private let healthDataTypes: Set<HKQuantityType> = {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return Set()
        }

        return Set([stepCountType, distanceType, activeEnergyType, heartRateType])
    }()

    // MARK: - Initialization
    private init() {
        checkHealthKitAvailability()
        loadPrivacySettings()
        Task {
            await setupHealthKitObservers()
        }
    }

    // MARK: - HealthKit Setup and Permissions

    /// Check if HealthKit is available on this device
    private func checkHealthKitAvailability() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    }

    /// Request HealthKit authorization
    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else {
            print("HealthKit not available on this device")
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)

            // Check authorization status for each type
            let stepCountAuth = healthStore.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .stepCount)!)
            let distanceAuth = healthStore.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!)

            isAuthorized = stepCountAuth == .sharingAuthorized && distanceAuth == .sharingAuthorized

            if isAuthorized {
                await setupHealthKitObservers()
                await loadTodaysData()
                await loadWeeklyData()
            }

            return isAuthorized
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    /// Setup HealthKit background observers for real-time data
    private func setupHealthKitObservers() async {
        guard isAuthorized else { return }

        // Setup observer for step count changes
        if let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let stepQuery = HKObserverQuery(sampleType: stepCountType, predicate: nil) { [weak self] _, _, error in
                if let error = error {
                    print("Step count observer error: \(error)")
                    return
                }

                Task { @MainActor in
                    await self?.updateRealTimeStepCount()
                }
            }

            healthStore.execute(stepQuery)
        }

        // Setup observer for distance changes
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let distanceQuery = HKObserverQuery(sampleType: distanceType, predicate: nil) { [weak self] _, _, error in
                if let error = error {
                    print("Distance observer error: \(error)")
                    return
                }

                Task { @MainActor in
                    await self?.updateRealTimeDistance()
                }
            }

            healthStore.execute(distanceQuery)
        }
    }

    // MARK: - Job Session Management

    /// Start tracking health data for a specific job
    func startJobSession(for job: Job) {
        guard isAuthorized && isTrackingEnabled else { return }

        // End any existing session
        if activeJobSession != nil {
            endJobSession()
        }

        // Create new session
        activeJobSession = JobHealthSession(
            id: UUID(),
            jobId: job.id,
            customerName: job.customerName,
            startTime: Date(),
            initialStepCount: currentStepCount,
            initialDistance: currentDistance
        )

        startRealTimeTracking()

        print("Started health tracking for job: \(job.customerName)")
    }

    /// End the current job session and save health data
    func endJobSession() {
        guard var session = activeJobSession else { return }

        // Update final values
        session.endTime = Date()
        session.finalStepCount = currentStepCount
        session.finalDistance = currentDistance
        session.totalStepsWalked = currentStepCount - session.initialStepCount
        session.totalDistanceWalked = currentDistance - session.initialDistance
        session.duration = session.endTime?.timeIntervalSince(session.startTime) ?? 0

        // Save session data to Core Data or local storage
        saveJobSession(session)

        // Stop real-time tracking
        stopRealTimeTracking()

        activeJobSession = nil

        print("Ended health tracking session. Steps: \(session.totalStepsWalked), Distance: \(session.totalDistanceWalked)")
    }

    // MARK: - Real-time Activity Tracking

    /// Start real-time step and activity tracking
    private func startRealTimeTracking() {
        guard CMPedometer.isStepCountingAvailable() else { return }

        // Start pedometer updates
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }

            DispatchQueue.main.async {
                self.updatePedometerData(data)
            }
        }

        // Start motion activity tracking
        if CMMotionActivityManager.isActivityAvailable() {
            motionManager.startActivityUpdates(to: OperationQueue.main) { [weak self] activity in
                guard let self = self, let activity = activity else { return }

                self.isActivelyWalking = activity.walking || activity.running
            }
        }

        // Start background task for continuous tracking
        startBackgroundTask()
    }

    /// Stop real-time tracking
    private func stopRealTimeTracking() {
        pedometer.stopUpdates()
        motionManager.stopActivityUpdates()
        endBackgroundTask()
    }

    /// Update pedometer data from CoreMotion
    private func updatePedometerData(_ data: CMPedometerData) {
        let steps = data.numberOfSteps.intValue
        currentStepCount = steps

        if let distance = data.distance?.doubleValue {
            currentDistance = distance
        }

        // Update active job session if running
        if var session = activeJobSession {
            session.currentStepCount = currentStepCount
            session.currentDistance = currentDistance
            activeJobSession = session
        }

        // Update activity summary
        updateActivitySummary()
    }

    // MARK: - HealthKit Data Queries

    /// Update real-time step count from HealthKit
    private func updateRealTimeStepCount() async {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            guard let self = self, let result = result, let sum = result.sumQuantity() else { return }

            DispatchQueue.main.async {
                self.currentStepCount = Int(sum.doubleValue(for: HKUnit.count()))
                self.todaysTotalSteps = self.currentStepCount
                self.updateActivitySummary()
            }
        }

        healthStore.execute(query)
    }

    /// Update real-time distance from HealthKit
    private func updateRealTimeDistance() async {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            guard let self = self, let result = result, let sum = result.sumQuantity() else { return }

            DispatchQueue.main.async {
                self.currentDistance = sum.doubleValue(for: HKUnit.meter())
                self.todaysTotalDistance = self.currentDistance
                self.updateActivitySummary()
            }
        }

        healthStore.execute(query)
    }

    /// Load today's total health data
    func loadTodaysData() async {
        await updateRealTimeStepCount()
        await updateRealTimeDistance()

        // Calculate total active time (placeholder - would need more complex calculation)
        todaysTotalActiveTime = activeJobSession?.duration ?? 0
    }

    /// Load weekly health data for statistics
    func loadWeeklyData() async {
        await loadWeeklyStepsData()
        await loadWeeklyDistanceData()
    }

    /// Load weekly steps data
    private func loadWeeklyStepsData() async {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -6, to: endDate)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )

        query.initialResultsHandler = { [weak self] _, collection, error in
            guard let self = self, let collection = collection else { return }

            var weeklyData: [DailyStepsData] = []

            collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let steps = Int(statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                let data = DailyStepsData(id: UUID(), date: statistics.startDate, steps: steps)
                weeklyData.append(data)
            }

            DispatchQueue.main.async {
                self.weeklyStepsData = weeklyData
                self.updateActivitySummary()
            }
        }

        healthStore.execute(query)
    }

    /// Load weekly distance data
    private func loadWeeklyDistanceData() async {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }

        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -6, to: endDate)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: distanceType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )

        query.initialResultsHandler = { [weak self] _, collection, error in
            guard let self = self, let collection = collection else { return }

            var weeklyData: [DailyDistanceData] = []

            collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let distance = statistics.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0
                let data = DailyDistanceData(id: UUID(), date: statistics.startDate, distanceMeters: distance)
                weeklyData.append(data)
            }

            DispatchQueue.main.async {
                self.weeklyDistanceData = weeklyData
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Data Persistence

    /// Save job health session to local storage
    private func saveJobSession(_ session: JobHealthSession) {
        // In a real implementation, this would save to Core Data
        // For now, we'll store in UserDefaults as an example

        if let encoded = try? JSONEncoder().encode(session) {
            let key = "health_session_\(session.jobId.uuidString)"
            UserDefaults.standard.set(encoded, forKey: key)

            // Also add to a list of all sessions
            var sessionIds = UserDefaults.standard.array(forKey: "all_health_sessions") as? [String] ?? []
            sessionIds.append(session.jobId.uuidString)
            UserDefaults.standard.set(sessionIds, forKey: "all_health_sessions")
        }
    }

    /// Load health session for a specific job
    func loadHealthSession(for jobId: UUID) -> JobHealthSession? {
        let key = "health_session_\(jobId.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let session = try? JSONDecoder().decode(JobHealthSession.self, from: data) else {
            return nil
        }
        return session
    }

    /// Get all health sessions
    func getAllHealthSessions() -> [JobHealthSession] {
        let sessionIds = UserDefaults.standard.array(forKey: "all_health_sessions") as? [String] ?? []

        return sessionIds.compactMap { sessionId in
            guard let uuid = UUID(uuidString: sessionId) else { return nil }
            return loadHealthSession(for: uuid)
        }
    }

    /// Clear all health data (for privacy compliance)
    func clearAllHealthData() {
        // Clear all health session data
        let sessionIds = UserDefaults.standard.array(forKey: "all_health_sessions") as? [String] ?? []
        for sessionId in sessionIds {
            let key = "health_session_\(sessionId)"
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Clear the session list
        UserDefaults.standard.removeObject(forKey: "all_health_sessions")

        // Clear privacy settings (reset to default)
        UserDefaults.standard.removeObject(forKey: "health_privacy_settings")
        privacySettings = HealthPrivacySettings()

        // Stop any active session
        activeJobSession = nil

        // Reset current values
        currentStepCount = 0
        currentDistance = 0.0
        currentActiveCalories = 0.0
        isActivelyWalking = false
        todaysTotalSteps = 0
        todaysTotalDistance = 0.0
        todaysTotalActiveTime = 0

        // Update summary
        updateActivitySummary()
    }

    // MARK: - Privacy Settings

    /// Load privacy settings
    private func loadPrivacySettings() {
        if let data = UserDefaults.standard.data(forKey: "health_privacy_settings"),
           let settings = try? JSONDecoder().decode(HealthPrivacySettings.self, from: data) {
            privacySettings = settings
        }

        isTrackingEnabled = privacySettings.allowHealthTracking
    }

    /// Save privacy settings
    func updatePrivacySettings(_ settings: HealthPrivacySettings) {
        privacySettings = settings
        isTrackingEnabled = settings.allowHealthTracking

        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "health_privacy_settings")
        }

        // If tracking is disabled, stop any active sessions
        if !isTrackingEnabled {
            endJobSession()
        }
    }

    // MARK: - Background Task Management

    /// Start background task for continuous health tracking
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "HealthTracking") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    /// End background task
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - Utility Methods

    /// Format distance for display
    func formatDistance(_ meters: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale

        let distance = Measurement(value: meters, unit: UnitLength.meters)
        return formatter.string(from: distance)
    }

    /// Format duration for display
    func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0s"
    }

    /// Calculate calories burned estimate
    func estimateCaloriesBurned(steps: Int, duration: TimeInterval) -> Double {
        // Rough estimate: 0.04 calories per step for average person
        // This would be more accurate with user height, weight, and heart rate
        return Double(steps) * 0.04
    }
}

// MARK: - Integration with RouteViewModel

extension HealthKitManager {

    /// Integration method to start tracking when job starts
    func handleJobStart(_ job: Job) {
        guard privacySettings.allowHealthTracking else { return }
        startJobSession(for: job)
        updateActivitySummary()
    }

    /// Integration method to stop tracking when job completes
    func handleJobComplete(_ job: Job) {
        guard activeJobSession?.jobId == job.id else { return }
        endJobSession()
        updateActivitySummary()
    }

    /// Update the published activity summary
    private func updateActivitySummary() {
        currentActivitySummary = ActivitySummary(
            currentSteps: currentStepCount,
            currentDistance: currentDistance,
            isActivelyWalking: isActivelyWalking,
            sessionSteps: activeJobSession?.totalStepsWalked ?? 0,
            sessionDistance: activeJobSession?.totalDistanceWalked ?? 0.0,
            sessionDuration: activeJobSession?.duration ?? 0,
            todaySteps: todaysTotalSteps,
            todayDistance: todaysTotalDistance,
            weeklyAverage: weeklyStepsData.isEmpty ? 0 : weeklyStepsData.map(\.steps).reduce(0, +) / weeklyStepsData.count
        )
    }
}