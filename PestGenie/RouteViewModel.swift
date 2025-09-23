import Foundation
import Combine
import Network

/// View model responsible for managing the daily route. Publishes changes
/// whenever jobs are added, removed, reordered or modified. In a production
/// environment this view model would communicate with a backend service via
/// networking layers. Here it uses in‑memory sample data to simplify the
/// example.
final class RouteViewModel: ObservableObject {
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

    // MARK: - Offline mode support
    /// Flag indicating whether the app is currently online. In a real app this
    /// would be driven by network reachability monitoring. Here it can be
    /// toggled manually for testing offline behaviours.
    @Published var isOnline: Bool = true
    /// Queue of actions performed while offline. When connectivity is
    /// restored, these will be sent to the server in order.
    private(set) var pendingActions: [PendingAction] = []



    init() {
        // Preload sample jobs immediately
        loadSampleData()
        
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
        jobs = [
            Job(id: UUID(), customerName: "Smith Residence", address: "123 Maple Street", scheduledDate: formatter.date(from: "2025-08-05 08:00")!, latitude: 40.2783, longitude: -111.7227, notes: "Gate code 1234", pinnedNotes: "Beware of dog", status: .pending),
            Job(id: UUID(), customerName: "Brown Residence", address: "456 Oak Avenue", scheduledDate: formatter.date(from: "2025-08-05 09:30")!, latitude: 40.2815, longitude: -111.7210, notes: nil, pinnedNotes: nil, status: .pending),
            Job(id: UUID(), customerName: "Johnson Residence", address: "789 Pine Lane", scheduledDate: formatter.date(from: "2025-08-05 11:00")!, latitude: 40.2800, longitude: -111.7200, notes: "Call before arrival", pinnedNotes: "Customer has bee allergy", status: .pending)
        ]
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
        return "Alex Rodriguez" // In production, this would come from user profile
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

    /// Load today's route data (placeholder for production implementation)
    func loadTodaysRoute() {
        // In production, this would fetch today's specific route from the server
        // For now, we use the existing sample data
        if jobs.isEmpty {
            loadSampleData()
        }
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