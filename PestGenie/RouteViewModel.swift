import Foundation
import Combine
import Network

/// View model responsible for managing the daily route. Publishes changes
/// whenever jobs are added, removed, reordered or modified. In a production
/// environment this view model would communicate with a backend service via
/// networking layers. Here it uses in‑memory sample data to simplify the
/// example.
final class RouteViewModel: ObservableObject {

    // MARK: - Health Tracking Integration
    @Published var healthManager: HealthKitManager
    @Published var isHealthTrackingEnabled: Bool = true
    @Published var currentActivitySummary: ActivitySummary?
    private var healthCancellables = Set<AnyCancellable>()

    // MARK: - Authentication
    private var authManager: AuthenticationManager? = nil
    @Published var currentUserName: String = "Technician"
    private var authCancellable: AnyCancellable?

    /// Set the authentication manager for user profile data
    @MainActor
    func setAuthenticationManager(_ authManager: AuthenticationManager) {
        self.authManager = authManager

        // Set initial user name if user is already authenticated
        if let currentUser = authManager.currentUser {
            currentUserName = currentUser.name ?? "Technician"
        }

        // Subscribe to authentication changes and update the stored user name
        authCancellable = authManager.$currentUser
            .receive(on: DispatchQueue.main)
            .map { user in
                user?.name ?? "Technician"
            }
            .assign(to: \.currentUserName, on: self)
    }
    @Published var jobs: [Job] = []
    @Published var selectedReason: ReasonCode? = nil
    @Published var isShowingReasonPicker: Bool = false
    @Published var activeJob: Job? = nil
    @Published var pendingMove: (Int, Int)? = nil
    @Published var pendingSkip: Job? = nil

    // MARK: - SDUI input values
    /// Stores values for text fields keyed by a composite key (valueKey + job ID or "global").
    @Published var textFieldValues: [String: String] = [:]
    /// Stores values for toggles keyed by a composite key.
    @Published var toggleValues: [String: Bool] = [:]
    /// Stores values for sliders keyed by a composite key.
    @Published var sliderValues: [String: Double] = [:]
    /// Stores values for pickers keyed by a composite key.
    @Published var pickerValues: [String: String] = [:]
    /// Stores values for date pickers keyed by a composite key.
    @Published var datePickerValues: [String: Date] = [:]
    /// Stores values for steppers keyed by a composite key.
    @Published var stepperValues: [String: Double] = [:]
    /// Stores values for segmented controls keyed by a composite key.
    @Published var segmentedValues: [String: Int] = [:]
    /// Stores presentation state for sheets/alerts keyed by a composite key.
    @Published var presentationStates: [String: Bool] = [:]
    /// Stores multi-select values for components that allow multiple selection.
    @Published var multiSelectValues: [String: [String]] = [:]

    // MARK: - Demo & Route Management
    @Published var isRouteStarted: Bool = false
    @Published var routeStartTime: Date? = nil
    @Published var totalDistanceTraveled: Double = 0.0
    @Published var currentSpeed: Double = 0.0
    @Published var estimatedTimeToNextJob: TimeInterval = 0
    @Published var weatherConditions: String = "Clear, 72°F"
    @Published var demoMode: Bool = false
    @Published var hasActiveEmergency: Bool = false
    @Published var currentEmergency: String? = nil

    // MARK: - Offline mode support
    /// Flag indicating whether the app is currently online. In a real app this
    /// would be driven by network reachability monitoring. Here it can be
    /// toggled manually for testing offline behaviours.
    @Published var isOnline: Bool = true
    /// Queue of actions performed while offline. When connectivity is
    /// restored, these will be sent to the server in order.
    private(set) var pendingActions: [PendingAction] = []



    init() {
        // Initialize health manager
        self.healthManager = HealthKitManager.shared

        // Preload sample jobs immediately
        loadSampleData()

        // Setup health tracking integration
        setupHealthTracking()

        // Defer network monitoring until first access
        // setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        // Start monitoring network connectivity. This uses NWPathMonitor to set
        // the `isOnline` flag based on whether a network path is satisfied.
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                let currentlyOnline = path.status == .satisfied
                // Only update if the status actually changed to avoid unnecessary
                // publishes. When transitioning from offline to online,
                // synchronise any pending actions.
                if self.isOnline != currentlyOnline {
                    self.isOnline = currentlyOnline
                    if currentlyOnline {
                        self.syncPendingActions()
                    }
                }
            }
        }
        let queue = DispatchQueue(label: "RouteViewModelNetworkMonitor")
        monitor.start(queue: queue)
    }
    
    /// Start network monitoring (call when needed)
    func startNetworkMonitoring() {
        setupNetworkMonitoring()
    }

    private func loadSampleData() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        // Create realistic demo jobs for technician workflow demonstration
        jobs = [
            // Morning jobs - typical suburban route
            Job(id: UUID(), customerName: "Smith Residence", address: "123 Maple Street", scheduledDate: formatter.date(from: "2025-09-25 08:00")!, latitude: 40.2783, longitude: -111.7227, notes: "Gate code 1234. Customer works from home.", pinnedNotes: "⚠️ Beware of dog - German Shepherd", status: .pending),

            Job(id: UUID(), customerName: "Westfield Shopping Center", address: "456 Commerce Blvd", scheduledDate: formatter.date(from: "2025-09-25 08:45")!, latitude: 40.2815, longitude: -111.7210, notes: "Use service entrance. Contact facility manager first.", pinnedNotes: "🏢 Commercial account - high visibility", status: .pending),

            Job(id: UUID(), customerName: "Johnson Family", address: "789 Pine Lane", scheduledDate: formatter.date(from: "2025-09-25 09:30")!, latitude: 40.2800, longitude: -111.7200, notes: "Call 15min before arrival", pinnedNotes: "🐝 Customer has severe bee allergy - NO bee treatments", status: .pending),

            // Mid-morning - challenging locations
            Job(id: UUID(), customerName: "Mountain View Apartments", address: "321 Highland Dr, Unit 15B", scheduledDate: formatter.date(from: "2025-09-25 10:15")!, latitude: 40.2850, longitude: -111.7180, notes: "Basement unit. Parking in rear. Key from manager.", pinnedNotes: "🏠 Recurring ant problem - check moisture levels", status: .pending),

            Job(id: UUID(), customerName: "Green Valley Restaurant", address: "555 Food Court Way", scheduledDate: formatter.date(from: "2025-09-25 11:00")!, latitude: 40.2900, longitude: -111.7150, notes: "After hours only (before 9AM). Health inspector visit last week.", pinnedNotes: "🍽️ Food service - extra care with chemicals", status: .pending),

            // Late morning - residential priority
            Job(id: UUID(), customerName: "Davis Elderly Care", address: "888 Senior Living Blvd", scheduledDate: formatter.date(from: "2025-09-25 11:45")!, latitude: 40.2750, longitude: -111.7300, notes: "Sensitive residents. Use least toxic options.", pinnedNotes: "👴 Elderly facility - low-impact treatments only", status: .pending)
        ]
    }

    /// Load comprehensive demo data with varied scenarios
    func loadDemoData() {
        demoMode = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        jobs = [
            // Completed morning job
            Job(id: UUID(), customerName: "Early Bird Café", address: "100 Main Street", scheduledDate: formatter.date(from: "2025-09-25 06:30")!, latitude: 40.2700, longitude: -111.7400, notes: "Pre-opening treatment completed", pinnedNotes: "✅ Regular monthly service", status: .completed),

            // In-progress job
            Job(id: UUID(), customerName: "Smith Residence", address: "123 Maple Street", scheduledDate: formatter.date(from: "2025-09-25 08:00")!, latitude: 40.2783, longitude: -111.7227, notes: "Currently treating perimeter", pinnedNotes: "🐕 Large dog - friendly but energetic", status: .inProgress),

            // Priority jobs ahead
            Job(id: UUID(), customerName: "Emergency Call - Wilson Home", address: "999 Urgent Ave", scheduledDate: formatter.date(from: "2025-09-25 09:00")!, latitude: 40.2820, longitude: -111.7190, notes: "URGENT: Wasp nest near children's play area", pinnedNotes: "🚨 PRIORITY - Children at risk", status: .pending),

            // Regular scheduled jobs
            Job(id: UUID(), customerName: "Westfield Shopping Center", address: "456 Commerce Blvd", scheduledDate: formatter.date(from: "2025-09-25 09:45")!, latitude: 40.2815, longitude: -111.7210, notes: "Monthly preventive treatment", pinnedNotes: "🏢 High-traffic area - work efficiently", status: .pending),

            Job(id: UUID(), customerName: "Johnson Family", address: "789 Pine Lane", scheduledDate: formatter.date(from: "2025-09-25 10:30")!, latitude: 40.2800, longitude: -111.7200, notes: "Follow-up from last week's treatment", pinnedNotes: "🏡 Repeat customer - very satisfied", status: .pending),

            // Challenging afternoon jobs
            Job(id: UUID(), customerName: "Hillside Mansion", address: "1200 Luxury Lane", scheduledDate: formatter.date(from: "2025-09-25 11:15")!, latitude: 40.2890, longitude: -111.7120, notes: "Large property - estimate 2-3 hours", pinnedNotes: "💰 Premium client - white-glove service", status: .pending),

            Job(id: UUID(), customerName: "Industrial Complex", address: "500 Factory Rd", scheduledDate: formatter.date(from: "2025-09-25 13:00")!, latitude: 40.2950, longitude: -111.7080, notes: "Safety equipment required. Check in at gate.", pinnedNotes: "🏭 Industrial site - follow all safety protocols", status: .pending),

            // End-of-day wrap up
            Job(id: UUID(), customerName: "Sunset Retirement Community", address: "777 Golden Years Dr", scheduledDate: formatter.date(from: "2025-09-25 15:30")!, latitude: 40.2680, longitude: -111.7450, notes: "Gentle treatments for sensitive environment", pinnedNotes: "👥 Many residents - minimal disruption", status: .pending)
        ]

        // Set one job as started if in demo mode
        if let firstPendingIndex = jobs.firstIndex(where: { $0.status == .inProgress }) {
            jobs[firstPendingIndex].startTime = Date().addingTimeInterval(-1800) // Started 30 min ago
        }
    }

    func moveJob(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        activeJob = jobs[sourceIndex]
        isShowingReasonPicker = true
        pendingMove = (sourceIndex, destination)
    }

    func commitMove() {
        guard let move = pendingMove else { return }
        let (sourceIndex, destination) = move
        let job = jobs.remove(at: sourceIndex)
        jobs.insert(job, at: destination)
        pendingMove = nil
        // If offline, record the move for later sync
        if !isOnline {
            let action = PendingAction(type: .move, jobId: job.id, valueKey: nil, value: "\(sourceIndex)->\(destination)", timestamp: Date())
            pendingActions.append(action)
        }
    }

    func skip(job: Job) {
        activeJob = job
        isShowingReasonPicker = true
        pendingSkip = job
    }

    func commitSkip() {
        guard let job = pendingSkip else { return }
        if let index = jobs.firstIndex(of: job) {
            jobs[index].status = .skipped
        }
        pendingSkip = nil
        if !isOnline {
            let action = PendingAction(type: .skip, jobId: job.id, valueKey: nil, value: nil, timestamp: Date())
            pendingActions.append(action)
        }
    }

    func start(job: Job) {
        if let index = jobs.firstIndex(of: job) {
            jobs[index].status = .inProgress
            jobs[index].startTime = Date()

            // Record equipment start times for usage tracking
            recordEquipmentStartTimes(for: jobs[index])

            // Start health tracking for this job
            Task { @MainActor in
                healthManager.handleJobStart(jobs[index])
            }

            // Queue action if offline
            if !isOnline {
                let action = PendingAction(type: .start, jobId: job.id, valueKey: nil, value: nil, timestamp: Date())
                pendingActions.append(action)
            }
        }
    }

    func complete(job: Job, signature: Data) {
        if let index = jobs.firstIndex(of: job) {
            jobs[index].status = .completed
            jobs[index].completionTime = Date()
            jobs[index].signatureData = signature

            // Record equipment usage for completed job
            recordEquipmentUsageForJob(jobs[index])

            // End health tracking for this job
            Task { @MainActor in
                healthManager.handleJobComplete(jobs[index])
            }

            // Queue action if offline
            if !isOnline {
                let action = PendingAction(type: .complete, jobId: job.id, valueKey: nil, value: nil, timestamp: Date())
                pendingActions.append(action)
            }
        }
    }

    // MARK: - SDUI input setters

    /// Sets a text value for the given composite key and queues an action if offline.
    func setTextValue(forKey key: String, value: String) {
        textFieldValues[key] = value
        if !isOnline {
            let action = PendingAction(type: .textInput, jobId: nil, valueKey: key, value: value, timestamp: Date())
            pendingActions.append(action)
        }
    }

    /// Sets a toggle value for the given composite key and queues an action if offline.
    func setToggleValue(forKey key: String, value: Bool) {
        toggleValues[key] = value
        if !isOnline {
            let action = PendingAction(type: .toggleInput, jobId: nil, valueKey: key, value: String(value), timestamp: Date())
            pendingActions.append(action)
        }
    }

    /// Sets a slider value for the given composite key and queues an action if offline.
    func setSliderValue(forKey key: String, value: Double) {
        sliderValues[key] = value
        if !isOnline {
            let action = PendingAction(type: .sliderInput, jobId: nil, valueKey: key, value: String(value), timestamp: Date())
            pendingActions.append(action)
        }
    }

    /// Sets a picker value for the given composite key and queues an action if offline.
    func setPickerValue(forKey key: String, value: String) {
        pickerValues[key] = value
        if !isOnline {
            let action = PendingAction(type: .pickerInput, jobId: nil, valueKey: key, value: value, timestamp: Date())
            pendingActions.append(action)
        }
    }

    /// Sets a date picker value for the given composite key and queues an action if offline.
    func setDatePickerValue(forKey key: String, value: Date) {
        datePickerValues[key] = value
        if !isOnline {
            let action = PendingAction(type: .datePickerInput, jobId: nil, valueKey: key, value: ISO8601DateFormatter().string(from: value), timestamp: Date())
            pendingActions.append(action)
        }
    }

    /// Sets a stepper value for the given composite key and queues an action if offline.
    func setStepperValue(forKey key: String, value: Double) {
        stepperValues[key] = value
        if !isOnline {
            let action = PendingAction(type: .stepperInput, jobId: nil, valueKey: key, value: String(value), timestamp: Date())
            pendingActions.append(action)
        }
    }

    /// Sets a segmented control value for the given composite key and queues an action if offline.
    func setSegmentedValue(forKey key: String, value: Int) {
        segmentedValues[key] = value
        if !isOnline {
            let action = PendingAction(type: .segmentedInput, jobId: nil, valueKey: key, value: String(value), timestamp: Date())
            pendingActions.append(action)
        }
    }

    /// Sets a presentation state for the given composite key.
    func setPresentationState(forKey key: String, value: Bool) {
        presentationStates[key] = value
    }

    /// Sets multi-select values for the given composite key and queues an action if offline.
    func setMultiSelectValues(forKey key: String, values: [String]) {
        multiSelectValues[key] = values
        if !isOnline {
            let action = PendingAction(type: .multiSelectInput, jobId: nil, valueKey: key, value: values.joined(separator: ","), timestamp: Date())
            pendingActions.append(action)
        }
    }

    // MARK: - Offline sync

    /// Attempts to synchronise any pending actions when coming back online. In a real app
    /// this would call backend APIs. Here we simply clear the queue and print actions.
    func syncPendingActions() {
        guard isOnline else { return }
        for action in pendingActions {
            // TODO: send to backend. For now just print.
            print("Syncing action: \(action)")
        }
        pendingActions.removeAll()
    }

    // MARK: - Dashboard Support

    /// Technician name for dashboard display
    var technicianName: String {
        return currentUserName
    }

    /// Current route identifier for display
    var currentRouteId: String {
        return "RT-2024-001" // In production, this would be the actual route ID
    }

    /// Number of completed jobs today
    var completedJobsCount: Int {
        return jobs.filter { $0.status == .completed }.count
    }

    /// Number of remaining jobs today
    var remainingJobsCount: Int {
        return jobs.filter { $0.status == .pending || $0.status == .inProgress }.count
    }

    /// Completion percentage for today's route
    var completionPercentage: Double {
        guard !jobs.isEmpty else { return 0.0 }
        return Double(completedJobsCount) / Double(jobs.count)
    }

    /// Weekly jobs completed (mock data for now)
    var weeklyJobsCompleted: Int {
        // In production, this would calculate actual weekly completion
        return completedJobsCount * 7 + 12 // Mock weekly data
    }

    /// Active streak days (mock data for now)
    var activeStreak: Int {
        // In production, this would track consecutive days with completed jobs
        return 5 // Mock streak data
    }

    /// Set SDUI template value for profile screen data binding
    func setSDUIValue(_ key: String, value: String) {
        setTextValue(forKey: key, value: value)
    }

    /// Load today's route data (placeholder for production implementation)
    func loadTodaysRoute() {
        // In production, this would fetch today's specific route from the server
        // For now, we use the existing sample data
        if jobs.isEmpty {
            loadSampleData()
        }
    }

    // MARK: - Route Management & Demo Functions

    /// Start the daily route with tracking
    func startRoute() {
        isRouteStarted = true
        routeStartTime = Date()
        totalDistanceTraveled = 0.0

        // Start simulated tracking updates if in demo mode
        if demoMode {
            startDemoTracking()
        }

        if !isOnline {
            let action = PendingAction(type: .routeStart, jobId: nil, valueKey: "route_start", value: ISO8601DateFormatter().string(from: Date()), timestamp: Date())
            pendingActions.append(action)
        }
    }

    /// End the daily route
    func endRoute() {
        isRouteStarted = false
        routeStartTime = nil
        currentSpeed = 0.0
        estimatedTimeToNextJob = 0

        if !isOnline {
            let action = PendingAction(type: .routeEnd, jobId: nil, valueKey: "route_end", value: ISO8601DateFormatter().string(from: Date()), timestamp: Date())
            pendingActions.append(action)
        }
    }

    /// Simulate realistic technician workflow progression for demos
    func progressDemoJobs() {
        guard demoMode else { return }

        // Simulate realistic job progression every few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.simulateJobProgression()
        }
    }

    private func simulateJobProgression() {
        // Find next logical job to progress
        if let inProgressJob = jobs.first(where: { $0.status == .inProgress }) {
            // Complete in-progress job after some time
            if let startTime = inProgressJob.startTime,
               Date().timeIntervalSince(startTime) > 120 { // 2 minutes in demo
                completeCurrentJob()
            }
        } else if let nextPendingJob = jobs.first(where: { $0.status == .pending }) {
            // Start next pending job
            start(job: nextPendingJob)
        }

        // Continue progression
        if jobs.contains(where: { $0.status == .pending || $0.status == .inProgress }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.simulateJobProgression()
            }
        }
    }

    private func completeCurrentJob() {
        guard let inProgressJob = jobs.first(where: { $0.status == .inProgress }) else { return }

        // Create mock signature data for demo
        let mockSignature = "Demo Signature Data".data(using: .utf8) ?? Data()
        complete(job: inProgressJob, signature: mockSignature)
    }

    private func startDemoTracking() {
        // Simulate GPS tracking updates
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            guard self.isRouteStarted else {
                timer.invalidate()
                return
            }

            // Update simulated metrics
            self.currentSpeed = Double.random(in: 15...45) // MPH
            self.totalDistanceTraveled += self.currentSpeed * (5.0 / 3600.0) // Distance in 5 seconds

            // Update weather periodically
            let weatherOptions = ["Clear, 72°F", "Partly cloudy, 68°F", "Overcast, 65°F", "Light rain, 60°F"]
            if Int.random(in: 1...10) == 1 {
                self.weatherConditions = weatherOptions.randomElement() ?? "Clear, 72°F"
            }

            // Calculate time to next job
            if self.jobs.first(where: { $0.status == .pending }) != nil {
                self.estimatedTimeToNextJob = TimeInterval.random(in: 300...1800) // 5-30 minutes
            }
        }
    }

    /// Toggle demo mode and load appropriate data
    func toggleDemoMode() {
        demoMode.toggle()
        if demoMode {
            loadDemoData()
            progressDemoJobs()
        } else {
            loadSampleData()
            endRoute()
        }
    }

    /// Quick demo scenarios for specific technician situations
    func loadEmergencyScenario() {
        demoMode = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        jobs = [
            // Active emergency
            Job(id: UUID(), customerName: "🚨 EMERGENCY - School District", address: "Emergency Call: Elementary School", scheduledDate: formatter.date(from: "2025-09-25 08:15")!, latitude: 40.2800, longitude: -111.7200, notes: "URGENT: Bees swarming playground during recess", pinnedNotes: "⚡ IMMEDIATE RESPONSE REQUIRED - Children evacuated", status: .inProgress),

            // Delayed jobs due to emergency
            Job(id: UUID(), customerName: "Smith Residence (DELAYED)", address: "123 Maple Street", scheduledDate: formatter.date(from: "2025-09-25 09:30")!, latitude: 40.2783, longitude: -111.7227, notes: "Customer notified of delay due to emergency", pinnedNotes: "ℹ️ Rescheduled - customer understanding", status: .pending)
        ]

        weatherConditions = "⚠️ High winds, 85°F - Use extra caution"
        isRouteStarted = true
        routeStartTime = Date().addingTimeInterval(-900) // Started 15 min ago
        hasActiveEmergency = true
        currentEmergency = "🚨 ACTIVE EMERGENCY: Bee swarm at elementary school"
    }

    // MARK: - Health Tracking Integration

    /// Setup health tracking integration
    private func setupHealthTracking() {
        Task { @MainActor in
            // Subscribe to health manager updates
            healthManager.$currentActivitySummary
                .receive(on: DispatchQueue.main)
                .sink { [weak self] activitySummary in
                    self?.currentActivitySummary = activitySummary
                }
                .store(in: &healthCancellables)

            // Update health tracking enabled state
            healthManager.$isTrackingEnabled
                .receive(on: DispatchQueue.main)
                .assign(to: \.isHealthTrackingEnabled, on: self)
                .store(in: &healthCancellables)

            // Request health authorization if enabled
            if isHealthTrackingEnabled {
                let authorized = await healthManager.requestAuthorization()
                if authorized {
                    await healthManager.loadTodaysData()
                }
            }
        }
    }

    /// Get health data for a specific job
    @MainActor
    func getJobHealthData(for jobId: UUID) -> JobHealthSession? {
        return healthManager.loadHealthSession(for: jobId)
    }

    /// Get all health sessions for analytics
    @MainActor
    func getAllHealthSessions() -> [JobHealthSession] {
        return healthManager.getAllHealthSessions()
    }

    /// Update health privacy settings
    @MainActor
    func updateHealthPrivacySettings(_ settings: HealthPrivacySettings) {
        healthManager.updatePrivacySettings(settings)
        isHealthTrackingEnabled = settings.allowHealthTracking
    }

    /// Toggle health tracking
    @MainActor
    func toggleHealthTracking() {
        let newSettings = HealthPrivacySettings(
            allowHealthTracking: !isHealthTrackingEnabled,
            allowDataSharing: healthManager.privacySettings.allowDataSharing,
            allowWeeklyReports: healthManager.privacySettings.allowWeeklyReports,
            trackOnlyDuringJobs: healthManager.privacySettings.trackOnlyDuringJobs,
            shareWithAppleHealth: healthManager.privacySettings.shareWithAppleHealth,
            privacyLevel: healthManager.privacySettings.privacyLevel
        )
        updateHealthPrivacySettings(newSettings)
    }

    /// Get health summary for dashboard
    @MainActor
    var healthSummaryForDashboard: ActivitySummary? {
        return currentActivitySummary ?? healthManager.currentActivitySummary
    }

    /// Health insights for the current week
    @MainActor
    func getWeeklyHealthInsights() -> [HealthInsight] {
        let sessions = getAllHealthSessions()
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()

        let weekSessions = sessions.filter { session in
            session.startTime >= weekStart && session.startTime <= weekEnd
        }

        let totalSteps = weekSessions.reduce(0) { $0 + $1.totalStepsWalked }
        let totalDistance = weekSessions.reduce(0.0) { $0 + $1.totalDistanceWalked }
        let totalActiveTime = weekSessions.reduce(0.0) { $0 + $1.duration }

        let report = WeeklyHealthReport(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            totalSteps: totalSteps,
            totalDistance: totalDistance,
            totalActiveTime: totalActiveTime,
            averageDailySteps: weekSessions.isEmpty ? 0 : totalSteps / 7,
            averageDailyDistance: weekSessions.isEmpty ? 0.0 : totalDistance / 7.0,
            jobSessions: weekSessions,
            insights: []
        )

        return WeeklyHealthReport.generateInsights(from: report)
    }

    // MARK: - Chemical Inventory Management

    @Published var chemicals: [Chemical] = []
    @Published var chemicalTreatments: [ChemicalTreatment] = []

    // MARK: - Equipment Management

    @Published var assignedEquipment: [Equipment] = []
    @Published var equipmentInspections: [EquipmentInspection] = []
    @Published var preServiceChecklistCompleted = false
    @Published var equipmentUsageLog: [EquipmentUsageRecord] = []

    /// Updates chemical inventory after a treatment application
    func recordChemicalUsage(chemicalId: UUID, quantityUsed: Double, jobId: UUID, notes: String = "") {
        // Update chemical inventory
        if let index = chemicals.firstIndex(where: { $0.id == chemicalId }) {
            chemicals[index].quantityInStock = max(0, chemicals[index].quantityInStock - quantityUsed)
            chemicals[index].lastModified = Date()
        }

        // Create treatment record
        let chemical = chemicals.first(where: { $0.id == chemicalId })
        let treatment = ChemicalTreatment(
            jobId: jobId,
            chemicalId: chemicalId,
            applicatorName: currentUserName,
            applicationDate: Date(),
            applicationMethod: .spray, // Default method
            targetPests: chemical?.targetPests ?? [],
            treatmentLocation: "Job Site", // Default location
            areaTreated: 1000.0, // Default area in sq ft
            quantityUsed: quantityUsed,
            dosageRate: quantityUsed / 1000.0, // Simple dosage calculation
            concentrationUsed: chemical?.concentration ?? 0.0,
            dilutionRatio: "1:1",
            weatherConditions: nil, // No weather snapshot for now
            environmentalConditions: getCurrentWeatherSummary(),
            notes: notes.isEmpty ? nil : notes
        )

        chemicalTreatments.append(treatment)

        // Queue action for sync
        if !isOnline {
            let action = PendingAction(
                type: .chemicalUsage,
                jobId: jobId,
                valueKey: "chemical_\(chemicalId.uuidString)",
                value: "\(quantityUsed)",
                timestamp: Date()
            )
            pendingActions.append(action)
        }

        // Check for low stock and send notification
        if let chemical = chemicals.first(where: { $0.id == chemicalId }), chemical.isLowStock {
            Task {
                await NotificationManager.shared.scheduleChemicalLowStockAlert(for: chemical)
            }
        }
    }

    /// Manually adjusts chemical inventory (restocking, corrections, etc.)
    func adjustChemicalInventory(chemicalId: UUID, adjustment: Double, reason: InventoryAdjustmentReason, notes: String = "") {
        if let index = chemicals.firstIndex(where: { $0.id == chemicalId }) {
            chemicals[index].quantityInStock = max(0, chemicals[index].quantityInStock + adjustment)
            chemicals[index].lastModified = Date()

            // Log the adjustment
            let record = InventoryAdjustment(
                chemicalId: chemicalId,
                adjustmentAmount: adjustment,
                reason: reason,
                notes: notes,
                technicianName: currentUserName,
                timestamp: Date()
            )

            // In production, this would be saved to Core Data
            print("Inventory adjustment recorded: \(record)")

            // Queue action for sync
            if !isOnline {
                let action = PendingAction(
                    type: .inventoryAdjustment,
                    jobId: nil,
                    valueKey: "adjust_\(chemicalId.uuidString)",
                    value: "\(adjustment)|\(reason.rawValue)|\(notes)",
                    timestamp: Date()
                )
                pendingActions.append(action)
            }
        }
    }

    /// Adds new chemical to inventory (initial stocking or new product)
    func addChemicalToInventory(_ chemical: Chemical) {
        if let existingIndex = chemicals.firstIndex(where: { $0.id == chemical.id }) {
            // Update existing chemical
            chemicals[existingIndex] = chemical
        } else {
            // Add new chemical
            chemicals.append(chemical)
        }

        // Queue action for sync
        if !isOnline {
            let action = PendingAction(
                type: .addChemical,
                jobId: nil,
                valueKey: "add_chemical_\(chemical.id.uuidString)",
                value: chemical.name,
                timestamp: Date()
            )
            pendingActions.append(action)
        }
    }

    /// Gets chemicals that are low in stock
    func getLowStockChemicals() -> [Chemical] {
        return chemicals.filter { $0.isLowStock }
    }

    /// Gets chemicals that are expired or near expiration
    func getExpiringChemicals() -> [Chemical] {
        return chemicals.filter { $0.isExpired || $0.isNearExpiration }
    }

    /// Calculates recommended order quantities for low stock chemicals
    func getReorderRecommendations() -> [ReorderRecommendation] {
        return getLowStockChemicals().map { chemical in
            ReorderRecommendation(
                chemical: chemical,
                recommendedQuantity: calculateReorderQuantity(for: chemical),
                priority: chemical.quantityInStock < 5.0 ? .high : .medium,
                estimatedDaysUntilEmpty: estimateDaysUntilEmpty(for: chemical)
            )
        }
    }

    // MARK: - Private Helper Methods

    private func getCurrentWeatherSummary() -> String {
        // In production, this would get actual weather data
        return "Clear, 72°F, 5mph wind"
    }

    private func calculateReentryTime(for chemicalId: UUID) -> Date {
        guard let chemical = chemicals.first(where: { $0.id == chemicalId }) else {
            return Date()
        }

        return Calendar.current.date(byAdding: .hour, value: chemical.reentryInterval, to: Date()) ?? Date()
    }

    private func calculateReorderQuantity(for chemical: Chemical) -> Double {
        // Simple algorithm: order enough for 30 days based on recent usage
        let recentUsage = chemicalTreatments
            .filter { $0.chemicalId == chemical.id }
            .filter { Calendar.current.dateComponents([.day], from: $0.applicationDate, to: Date()).day ?? 0 <= 30 }
            .reduce(0.0) { $0 + $1.quantityUsed }

        let dailyUsage = recentUsage / 30.0
        return max(dailyUsage * 30.0, 10.0) // Minimum 10 units
    }

    private func estimateDaysUntilEmpty(for chemical: Chemical) -> Int {
        let recentUsage = chemicalTreatments
            .filter { $0.chemicalId == chemical.id }
            .filter { Calendar.current.dateComponents([.day], from: $0.applicationDate, to: Date()).day ?? 0 <= 7 }
            .reduce(0.0) { $0 + $1.quantityUsed }

        let dailyUsage = recentUsage / 7.0

        if dailyUsage > 0 {
            return Int(chemical.quantityInStock / dailyUsage)
        } else {
            return 999 // Unknown usage pattern
        }
    }

    // MARK: - Equipment Management Methods

    /// Records equipment inspection before route start
    func recordEquipmentInspection(equipmentId: UUID, inspectionType: EquipmentInspectionType, result: InspectionResult, notes: String = "") {
        let inspection = EquipmentInspection(
            equipmentId: equipmentId,
            inspectorName: currentUserName,
            inspectionType: inspectionType,
            result: result,
            notes: notes,
            inspectionDate: Date()
        )

        equipmentInspections.append(inspection)

        // Update equipment status based on inspection result
        if let index = assignedEquipment.firstIndex(where: { $0.id == equipmentId }) {
            switch result {
            case .passed:
                assignedEquipment[index].status = .available
                assignedEquipment[index].lastInspectionDate = Date()
            case .failed:
                assignedEquipment[index].status = .maintenance
            case .conditionalPass:
                assignedEquipment[index].status = .available
                assignedEquipment[index].lastInspectionDate = Date()
            case .needsCalibration:
                assignedEquipment[index].status = .calibration
            case .needsMaintenance:
                assignedEquipment[index].status = .maintenance
            case .pending:
                // Keep current status for pending inspections
                break
            }
            assignedEquipment[index].lastModified = Date()
        }

        // Queue action for sync
        if !isOnline {
            let action = PendingAction(
                type: .equipmentInspection,
                jobId: nil,
                valueKey: "inspection_\(equipmentId.uuidString)",
                value: "\(result.rawValue)|\(notes)",
                timestamp: Date()
            )
            pendingActions.append(action)
        }
    }

    /// Records equipment usage during a job
    func recordEquipmentUsage(equipmentId: UUID, jobId: UUID, usageType: EquipmentUsageType, duration: TimeInterval, notes: String = "") {
        let usageRecord = EquipmentUsageRecord(
            equipmentId: equipmentId,
            jobId: jobId,
            technicianName: currentUserName,
            usageType: usageType,
            startTime: Date().addingTimeInterval(-duration),
            endTime: Date(),
            duration: duration,
            notes: notes
        )

        equipmentUsageLog.append(usageRecord)

        // Update equipment usage statistics
        if let index = assignedEquipment.firstIndex(where: { $0.id == equipmentId }) {
            var usageLog = UsageRecord(
                equipmentId: equipmentId,
                operatorId: "", // Will need to set from current user context
                operatorName: "" // Will need to set from current user context
            )
            usageLog.jobId = jobId
            usageLog.startTime = usageRecord.startTime
            usageLog.endTime = usageRecord.endTime
            usageLog.hours = duration / 3600.0 // Convert to hours
            usageLog.conditions = UsageConditions(
                temperature: nil,
                humidity: nil,
                terrain: nil,
                chemicalType: nil,
                workload: .moderate
            )
            usageLog.notes = notes
            assignedEquipment[index].usageLog.append(usageLog)
            assignedEquipment[index].lastModified = Date()
        }

        // Queue action for sync
        if !isOnline {
            let action = PendingAction(
                type: .equipmentUsage,
                jobId: jobId,
                valueKey: "usage_\(equipmentId.uuidString)",
                value: "\(duration)|\(usageType.rawValue)",
                timestamp: Date()
            )
            pendingActions.append(action)
        }
    }

    /// Completes pre-service checklist
    func completePreServiceChecklist() -> Bool {
        // Check that all assigned equipment has been inspected today
        let todayInspections = equipmentInspections.filter { inspection in
            Calendar.current.isDate(inspection.inspectionDate, inSameDayAs: Date())
        }

        let inspectedEquipmentIds = Set(todayInspections.map { $0.equipmentId })
        let assignedEquipmentIds = Set(assignedEquipment.map { $0.id })

        let allEquipmentInspected = assignedEquipmentIds.isSubset(of: inspectedEquipmentIds)
        let allInspectionsPassed = todayInspections.allSatisfy { $0.result == .passed }

        preServiceChecklistCompleted = allEquipmentInspected && allInspectionsPassed

        if preServiceChecklistCompleted {
            // Queue action for sync
            if !isOnline {
                let action = PendingAction(
                    type: .preServiceChecklist,
                    jobId: nil,
                    valueKey: "checklist_completed",
                    value: "true",
                    timestamp: Date()
                )
                pendingActions.append(action)
            }
        }

        return preServiceChecklistCompleted
    }

    /// Gets equipment that needs attention (maintenance, calibration, etc.)
    func getEquipmentNeedingAttention() -> [Equipment] {
        return assignedEquipment.filter { equipment in
            equipment.isMaintenanceDue || equipment.isCalibrationDue || equipment.status != .available
        }
    }

    /// Gets equipment ready for use
    func getReadyEquipment() -> [Equipment] {
        return assignedEquipment.filter { $0.isAvailable }
    }

    /// Gets recent equipment inspections
    func getRecentInspections(days: Int = 7) -> [EquipmentInspection] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return equipmentInspections.filter { $0.inspectionDate >= cutoffDate }
    }

    /// Initialize with demo equipment inventory
    func loadDemoEquipment() {
        assignedEquipment = [
            Equipment(
                name: "Backpack Sprayer",
                brand: "Solo",
                model: "BS-1025",
                serialNumber: "BSP-2024-001",
                type: .backpackSprayer,
                category: .sprayEquipment,
                purchaseDate: Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date(),
                specifications: EquipmentSpecifications()
            ),
            Equipment(
                name: "Moisture Meter",
                brand: "Protimeter",
                model: "MM-3012",
                serialNumber: "MM-2024-007",
                type: .moistureMeter,
                category: .detectionTools,
                purchaseDate: Calendar.current.date(byAdding: .month, value: -8, to: Date()) ?? Date(),
                specifications: EquipmentSpecifications()
            ),
            Equipment(
                name: "Inspection Camera",
                brand: "FLIR",
                model: "IC-2024",
                serialNumber: "IC-2024-015",
                type: .borescope,
                category: .detectionTools,
                purchaseDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(),
                specifications: EquipmentSpecifications()
            ),
            Equipment(
                name: "Digital Scale",
                brand: "Ohaus",
                model: "DS-Pro",
                serialNumber: "DS-2024-022",
                type: .thermometer,
                category: .detectionTools,
                purchaseDate: Calendar.current.date(byAdding: .month, value: -10, to: Date()) ?? Date(),
                specifications: EquipmentSpecifications()
            ),
            Equipment(
                name: "Tank Sprayer",
                brand: "Chapin",
                model: "TS-200",
                serialNumber: "TS-2024-003",
                type: .tankSprayer,
                category: .sprayEquipment,
                purchaseDate: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(),
                specifications: EquipmentSpecifications()
            ),
            Equipment(
                name: "Bait Station Tool",
                brand: "Xcluder",
                model: "BST-100",
                serialNumber: "BST-2024-012",
                type: .baitGun,
                category: .applicationTools,
                purchaseDate: Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date(),
                specifications: EquipmentSpecifications()
            )
        ]

        // Set some equipment to need attention for demo purposes
        if assignedEquipment.count >= 2 {
            assignedEquipment[1].status = .maintenance
            assignedEquipment[1].nextMaintenanceDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        }

        // Set additional equipment maintenance dates and inspection dates for demo
        if assignedEquipment.count >= 3 {
            assignedEquipment[2].lastInspectionDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
            assignedEquipment[2].nextMaintenanceDate = Calendar.current.date(byAdding: .month, value: 4, to: Date())
        }

        if assignedEquipment.count >= 4 {
            assignedEquipment[3].lastInspectionDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
            assignedEquipment[3].nextMaintenanceDate = Calendar.current.date(byAdding: .month, value: 5, to: Date())
        }

        if assignedEquipment.count >= 5 {
            assignedEquipment[4].lastInspectionDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
            assignedEquipment[4].nextMaintenanceDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
        }

        if assignedEquipment.count >= 6 {
            assignedEquipment[5].lastInspectionDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
            assignedEquipment[5].nextMaintenanceDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        }
    }

    // MARK: - Equipment Usage Tracking

    /// Records equipment start times when a job begins
    func recordEquipmentStartTimes(for job: Job) {
        guard let startTime = job.startTime else { return }

        // Mark all available equipment as in use for this job
        for equipment in assignedEquipment where equipment.isAvailable {
            // Update equipment status to in use
            if let index = assignedEquipment.firstIndex(where: { $0.id == equipment.id }) {
                assignedEquipment[index].status = .inUse
                assignedEquipment[index].lastUsageDate = startTime
            }
        }
    }

    /// Records equipment usage for a completed job
    func recordEquipmentUsageForJob(_ job: Job) {
        guard let startTime = job.startTime,
              let completionTime = job.completionTime else { return }

        let usageDuration = completionTime.timeIntervalSince(startTime)

        // Record usage for all assigned equipment used during the job
        for equipment in assignedEquipment {
            // Only record usage for equipment that was in use or available
            if equipment.status == .inUse || equipment.isAvailable {
                let usageRecord = EquipmentUsageRecord(
                    equipmentId: equipment.id,
                    jobId: job.id,
                    technicianName: "Current Technician", // TODO: Get from user profile
                    usageType: determineUsageType(for: equipment),
                    startTime: startTime,
                    endTime: completionTime,
                    duration: usageDuration,
                    notes: "Used for job: \(job.customerName)"
                )

                equipmentUsageLog.append(usageRecord)

                // Update equipment usage statistics
                updateEquipmentUsageStatistics(equipmentId: equipment.id, duration: usageDuration)

                // Reset equipment status to available after job completion
                if let index = assignedEquipment.firstIndex(where: { $0.id == equipment.id }) {
                    if assignedEquipment[index].status == .inUse {
                        assignedEquipment[index].status = .available
                    }
                }
            }
        }

        // Queue action for sync if offline
        if !isOnline {
            let action = PendingAction(
                type: .equipmentUsage,
                jobId: job.id,
                valueKey: "equipment_usage_recorded",
                value: "true",
                timestamp: Date()
            )
            pendingActions.append(action)
        }
    }

    /// Records individual equipment usage
    func recordEquipmentUsage(equipmentId: UUID, jobId: UUID, customerName: String, startTime: Date, endTime: Date, notes: String = "") {
        let usageDuration = endTime.timeIntervalSince(startTime)

        guard let equipment = assignedEquipment.first(where: { $0.id == equipmentId }) else { return }

        let usageRecord = EquipmentUsageRecord(
            equipmentId: equipmentId,
            jobId: jobId,
            technicianName: "Current Technician", // TODO: Get from user profile
            usageType: determineUsageType(for: equipment),
            startTime: startTime,
            endTime: endTime,
            duration: usageDuration,
            notes: notes
        )

        equipmentUsageLog.append(usageRecord)
        updateEquipmentUsageStatistics(equipmentId: equipmentId, duration: usageDuration)

        // Queue action for sync if offline
        if !isOnline {
            let action = PendingAction(
                type: .equipmentUsage,
                jobId: jobId,
                valueKey: "individual_equipment_usage",
                value: equipmentId.uuidString,
                timestamp: Date()
            )
            pendingActions.append(action)
        }
    }

    /// Gets equipment usage records for a specific equipment item
    func getEquipmentUsageHistory(equipmentId: UUID, days: Int = 30) -> [EquipmentUsageRecord] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return equipmentUsageLog
            .filter { $0.equipmentId == equipmentId && $0.startTime >= cutoffDate }
            .sorted { $0.startTime > $1.startTime }
    }

    /// Gets total usage hours for equipment over a period
    func getTotalUsageHours(equipmentId: UUID, days: Int = 30) -> Double {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentUsage = equipmentUsageLog.filter {
            $0.equipmentId == equipmentId && $0.startTime >= cutoffDate
        }

        let totalSeconds = recentUsage.reduce(into: 0) { $0 += $1.duration }
        return totalSeconds / 3600.0 // Convert to hours
    }

    /// Gets equipment usage for today
    func getTodaysEquipmentUsage() -> [EquipmentUsageRecord] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()

        return equipmentUsageLog.filter {
            $0.startTime >= today && $0.startTime < tomorrow
        }
    }

    // MARK: - Private Equipment Usage Helpers

    private func determineUsageType(for equipment: Equipment) -> EquipmentUsageType {
        switch equipment.category {
        case .sprayEquipment:
            return .spraying
        case .detectionTools:
            return .inspection
        case .safetyGear:
            return .transport
        case .applicationTools:
            return .spraying
        case .maintenanceTools:
            return .cleaning
        }
    }


    private func updateEquipmentUsageStatistics(equipmentId: UUID, duration: TimeInterval) {
        guard let index = assignedEquipment.firstIndex(where: { $0.id == equipmentId }) else { return }

        // Update total usage time
        assignedEquipment[index].totalUsageHours += duration / 3600.0

        // Update last usage date
        assignedEquipment[index].lastUsageDate = Date()

        // Check if maintenance is needed based on usage
        checkMaintenanceSchedule(for: assignedEquipment[index])
    }

    private func checkMaintenanceSchedule(for equipment: Equipment) {
        // Example: Schedule maintenance every 100 hours of usage
        let maintenanceInterval: Double = 100.0

        if equipment.totalUsageHours >= maintenanceInterval && equipment.nextMaintenanceDate == nil {
            if let index = assignedEquipment.firstIndex(where: { $0.id == equipment.id }) {
                assignedEquipment[index].nextMaintenanceDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
                assignedEquipment[index].status = .maintenance
            }
        }
    }

    /// Initialize with demo chemical inventory
    func loadDemoChemicals() {
        chemicals = [
            Chemical(
                name: "Termidor SC",
                activeIngredient: "Fipronil 9.1%",
                manufacturerName: "BASF",
                epaRegistrationNumber: "7969-210",
                concentration: 9.1,
                unitOfMeasure: "gal",
                quantityInStock: 5.2,
                expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
                batchNumber: "TM2024-001",
                targetPests: ["Termites", "Ants"],
                signalWord: .caution,
                reentryInterval: 0
            ),
            Chemical(
                name: "Premise 2",
                activeIngredient: "Imidacloprid 21.4%",
                manufacturerName: "Bayer",
                epaRegistrationNumber: "432-1483",
                concentration: 21.4,
                unitOfMeasure: "gal",
                quantityInStock: 3.8,
                expirationDate: Calendar.current.date(byAdding: .month, value: 8, to: Date()) ?? Date(),
                batchNumber: "PR2024-055",
                targetPests: ["Termites"],
                signalWord: .caution,
                reentryInterval: 0
            ),
            Chemical(
                name: "Phantom II",
                activeIngredient: "Chlorfenapyr 21.45%",
                manufacturerName: "BASF",
                epaRegistrationNumber: "241-392",
                concentration: 21.45,
                unitOfMeasure: "gal",
                quantityInStock: 0.8,
                expirationDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date(),
                batchNumber: "PH2024-012",
                targetPests: ["Ants", "Cockroaches", "Bed bugs"],
                signalWord: .caution,
                reentryInterval: 24,
                storageRequirements: "Store in cool, dry place"
            ),
            Chemical(
                name: "Suspend SC",
                activeIngredient: "Deltamethrin 4.75%",
                manufacturerName: "Bayer",
                epaRegistrationNumber: "432-763",
                concentration: 4.75,
                unitOfMeasure: "gal",
                quantityInStock: 3.0,
                expirationDate: Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date(),
                batchNumber: "SU2024-089",
                targetPests: ["Ants", "Spiders", "Wasps"],
                signalWord: .caution,
                reentryInterval: 0
            )
        ]
    }
}

/// Represents an action performed while offline. These actions are queued and
/// later sent to the server when connectivity is restored. Additional
/// parameters can be added as needed.
struct PendingAction: CustomStringConvertible {
    enum ActionType {
        case start
        case complete
        case skip
        case move
        case textInput
        case toggleInput
        case sliderInput
        case pickerInput
        case datePickerInput
        case stepperInput
        case segmentedInput
        case multiSelectInput
        case routeStart
        case routeEnd
        case chemicalUsage
        case inventoryAdjustment
        case addChemical
        case equipmentInspection
        case equipmentUsage
        case preServiceChecklist
    }
    let type: ActionType
    let jobId: UUID?
    let valueKey: String?
    let value: String?
    let timestamp: Date
    var description: String {
        "PendingAction(type: \(type), jobId: \(jobId?.uuidString ?? "nil"), key: \(valueKey ?? "nil"), value: \(value ?? "nil"), timestamp: \(timestamp))"
    }
}