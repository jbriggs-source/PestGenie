import SwiftUI

/// Professional SDUI Components Demo view that showcases the Server-Driven UI capabilities
/// This replaces the demo mode toggle and provides a comprehensive showcase of SDUI features
struct SDUIComponentsDemo: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var routeViewModel: RouteViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var authManager: AuthenticationManager

    @State private var screen: SDUIScreen? = nil
    @State private var selectedDemo: DemoType = .comprehensive

    enum DemoType: String, CaseIterable {
        case comprehensive = "TechnicianScreen_v5_complete"
        case advanced = "TechnicianScreen_v4_comprehensive"
        case basic = "TechnicianScreen_v3b"
        case simple = "TechnicianScreen"

        var title: String {
            switch self {
            case .comprehensive: return "Complete Demo"
            case .advanced: return "Advanced Components"
            case .basic: return "Basic Components"
            case .simple: return "Simple Layout"
            }
        }

        var description: String {
            switch self {
            case .comprehensive: return "Full showcase of all SDUI capabilities"
            case .advanced: return "Advanced layouts and interactions"
            case .basic: return "Essential components and patterns"
            case .simple: return "Basic text and layout elements"
            }
        }

        var icon: String {
            switch self {
            case .comprehensive: return "star.fill"
            case .advanced: return "gear.circle"
            case .basic: return "rectangle.3.group"
            case .simple: return "doc.text"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Demo selector
                VStack(spacing: 16) {
                    Text("Server-Driven UI Components")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Explore how UI components are dynamically rendered from JSON configurations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Demo type picker
                    Picker("Demo Type", selection: $selectedDemo) {
                        ForEach(DemoType.allCases, id: \.self) { demo in
                            HStack {
                                Image(systemName: demo.icon)
                                Text(demo.title)
                            }
                            .tag(demo)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Demo description
                    HStack(spacing: 8) {
                        Image(systemName: selectedDemo.icon)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedDemo.title)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(selectedDemo.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)

                // SDUI content
                Group {
                    if let screen = screen {
                        SDUIScreenRenderer.render(screen: screen, context: buildContext())
                    } else {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)

                            Text("Loading SDUI Demo...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemGray6))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { selectedDemo = .comprehensive }) {
                            Label("Complete Demo", systemImage: "star.fill")
                        }

                        Button(action: { selectedDemo = .advanced }) {
                            Label("Advanced Components", systemImage: "gear.circle")
                        }

                        Button(action: { selectedDemo = .basic }) {
                            Label("Basic Components", systemImage: "rectangle.3.group")
                        }

                        Button(action: { selectedDemo = .simple }) {
                            Label("Simple Layout", systemImage: "doc.text")
                        }

                        Divider()

                        Button(action: { loadScreen() }) {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadScreen()
        }
        .onChange(of: selectedDemo) { _, _ in
            loadScreen()
        }
    }

    // MARK: - Private Methods

    /// Builds the SDUI context with the current set of jobs and action handlers
    private func buildContext() -> SDUIContext {
        var actions: [String: (Job?) -> Void] = [:]

        // Demo actions that show alerts instead of real functionality
        actions["startJob"] = { job in
            showDemoAlert("Start Job", "This would start job: \(job?.customerName ?? "Unknown")")
        }

        actions["completeJob"] = { job in
            showDemoAlert("Complete Job", "This would complete job: \(job?.customerName ?? "Unknown")")
        }

        actions["skipJob"] = { job in
            showDemoAlert("Skip Job", "This would skip job: \(job?.customerName ?? "Unknown")")
        }

        // Use demo jobs for the showcase
        let demoJobs = createDemoJobs()

        return SDUIContext(
            jobs: demoJobs,
            routeViewModel: routeViewModel,
            actions: actions,
            currentJob: demoJobs.first,
            persistenceController: PersistenceController.shared,
            authManager: authManager
        )
    }

    /// Loads the selected demo screen from JSON
    private func loadScreen() {
        guard let url = Bundle.main.url(forResource: selectedDemo.rawValue, withExtension: "json", subdirectory: nil) else {
            print("Could not find \(selectedDemo.rawValue).json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let screen = try decoder.decode(SDUIScreen.self, from: data)

            withAnimation(.easeInOut(duration: 0.3)) {
                self.screen = screen
            }

            print("✅ Loaded SDUI demo from \(selectedDemo.rawValue).json")
        } catch {
            print("❌ Failed to decode \(selectedDemo.rawValue).json: \(error)")
            self.screen = nil
        }
    }

    /// Creates demo jobs for the SDUI showcase
    private func createDemoJobs() -> [Job] {
        return [
            Job(
                id: UUID(),
                customerName: "Smith Family",
                address: "123 Oak Street, Anytown USA",
                scheduledDate: Date(),
                latitude: nil,
                longitude: nil,
                notes: "Customer reports ant activity in kitchen area. Previous treatment 3 months ago.",
                pinnedNotes: nil,
                status: .pending,
                startTime: nil,
                completionTime: nil,
                signatureData: nil,
                weatherAtStart: nil,
                weatherAtCompletion: nil
            ),
            Job(
                id: UUID(),
                customerName: "Downtown Restaurant",
                address: "456 Main Street, Business District",
                scheduledDate: Date().addingTimeInterval(3600),
                latitude: nil,
                longitude: nil,
                notes: "Monthly inspection. Check bait stations and entry points.",
                pinnedNotes: nil,
                status: .inProgress,
                startTime: nil,
                completionTime: nil,
                signatureData: nil,
                weatherAtStart: nil,
                weatherAtCompletion: nil
            ),
            Job(
                id: UUID(),
                customerName: "Johnson Property",
                address: "789 Pine Avenue, Suburb Heights",
                scheduledDate: Date().addingTimeInterval(7200),
                latitude: nil,
                longitude: nil,
                notes: "Annual termite barrier treatment. All areas treated successfully.",
                pinnedNotes: nil,
                status: .completed,
                startTime: nil,
                completionTime: nil,
                signatureData: nil,
                weatherAtStart: nil,
                weatherAtCompletion: nil
            )
        ]
    }

    /// Shows a demo alert for action testing
    private func showDemoAlert(_ title: String, _ message: String) {
        // In a real implementation, you might want to use a proper alert system
        print("🎭 Demo Action - \(title): \(message)")
    }
}

// MARK: - Preview

#Preview {
    SDUIComponentsDemo()
        .environmentObject(RouteViewModel())
        .environmentObject(LocationManager.shared)
        .environmentObject(AuthenticationManager.shared)
}