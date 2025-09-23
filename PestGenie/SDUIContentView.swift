import SwiftUI

/// Top level view for the server driven technician application. It loads a JSON
/// definition from the app bundle (or could fetch from a server), decodes it
/// into SDUI structures and renders it using `SDUIScreenRenderer`. Domain
/// specific interactions like starting/finishing jobs, skipping and reordering
/// are provided to the SDUI engine via an actions map.
struct SDUIContentView: View {
    // Renamed to avoid collision with similarly named properties in SDUIContext.
    @EnvironmentObject private var routeViewModel: RouteViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @State private var screen: SDUIScreen? = nil
    @State private var jobAwaitingSignature: Job? = nil
    @State private var showingSignatureSheet: Bool = false

    var body: some View {
        Group {
            if let screen = screen {
                SDUIScreenRenderer.render(screen: screen, context: buildContext())
                    .navigationTitle("Today's Route")
                    .toolbar {
                        EditButton()
                    }
            } else {
                Text("Loading UI...")
            }
        }
        .onAppear {
            loadScreen()
            // Defer heavy initialization until after UI appears
            Task {
                await initializeServices()
            }
        }
        // When the connectivity status flips to online, synchronise any queued actions.
        .onChange(of: routeViewModel.isOnline) { _, online in
            if online {
                routeViewModel.syncPendingActions()
            }
        }
        .sheet(isPresented: $routeViewModel.isShowingReasonPicker, onDismiss: {
            if routeViewModel.pendingSkip != nil {
                routeViewModel.commitSkip()
            } else if routeViewModel.pendingMove != nil {
                routeViewModel.commitMove()
            }
        }) {
            ReasonPickerView(reason: $routeViewModel.selectedReason)
        }
        .sheet(isPresented: $showingSignatureSheet) {
            if let job = jobAwaitingSignature {
                SignatureView { data in
                    routeViewModel.complete(job: job, signature: data)
                    jobAwaitingSignature = nil
                }
            }
        }
    }
    /// Builds the SDUI context with the current set of jobs and action handlers.
    private func buildContext() -> SDUIContext {
        var actions: [String: (Job?) -> Void] = [:]
        actions["startJob"] = { job in
            if let job = job { routeViewModel.start(job: job) }
        }
        actions["completeJob"] = { job in
            if let job = job {
                // Show signature sheet before completing. Wrap in
                // DispatchQueue.main to ensure state updates occur on the main thread.
                DispatchQueue.main.async {
                    jobAwaitingSignature = job
                    showingSignatureSheet = true
                }
            }
        }
        actions["skipJob"] = { job in
            if let job = job { routeViewModel.skip(job: job) }
        }
        return SDUIContext(jobs: routeViewModel.jobs, routeViewModel: routeViewModel, actions: actions, currentJob: nil, persistenceController: PersistenceController.shared)
    }
    /// Loads the screen definition from the bundled JSON file. In a real app
    /// this could fetch from a remote service and cache it. This method
    /// attempts to load the most recent versioned screen first (e.g. v3),
    /// falling back to earlier versions if newer ones are unavailable. If
    /// decoding fails, the app prints an error and leaves `screen` nil.
    private func loadScreen() {
        let candidateNames = ["TechnicianScreen_v3", "TechnicianScreen_v2", "TechnicianScreen"]
        for name in candidateNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: nil) {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let screen = try decoder.decode(SDUIScreen.self, from: data)
                    self.screen = screen
                    print("Loaded screen from \(name).json")
                    return
                } catch {
                    print("Failed to decode \(name).json: \(error)")
                    continue
                }
            }
        }
        print("No screen JSON found in bundle")
    }
    
    /// Initialize heavy services after UI appears
    private func initializeServices() async {
        // Update location manager with current jobs from the route view model
        locationManager.monitoredJobs = routeViewModel.jobs
        
        // Start network monitoring
        routeViewModel.startNetworkMonitoring()
        
        // Start location monitoring in background
        await MainActor.run {
            locationManager.startMonitoring()
        }
        
        // Initialize other services asynchronously
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // Initialize maintenance system
                await MainActor.run {
                    _ = MaintenanceSchedulingManager.shared
                }
            }
            group.addTask {
                // Initialize calibration system  
                await MainActor.run {
                    _ = CalibrationTrackingManager.shared
                }
            }
            group.addTask {
                // Initialize sync manager
                await MainActor.run {
                    _ = SyncManager.shared
                }
            }
        }
    }
}