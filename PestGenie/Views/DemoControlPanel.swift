import SwiftUI

struct DemoControlPanel: View {
    @ObservedObject var routeViewModel: RouteViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Demo Status Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: routeViewModel.demoMode ? "waveform.badge.magnifyingglass" : "waveform")
                        .foregroundColor(routeViewModel.demoMode ? .blue : .gray)
                    Text(routeViewModel.demoMode ? "Demo Mode Active" : "Demo Mode")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { routeViewModel.demoMode },
                        set: { _ in routeViewModel.toggleDemoMode() }
                    ))
                }

                if routeViewModel.demoMode {
                    Text("Simulated technician workflow and live data updates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(routeViewModel.demoMode ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)

            if routeViewModel.demoMode {
                // Live Route Metrics
                LiveRouteMetrics(routeViewModel: routeViewModel)

                // Demo Scenario Controls
                DemoScenarioControls(routeViewModel: routeViewModel)

                // Job Progression Simulator
                JobProgressionView(routeViewModel: routeViewModel)
            }
        }
    }
}

struct LiveRouteMetrics: View {
    @ObservedObject var routeViewModel: RouteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.green)
                Text("Live Route Metrics")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: "Route Status",
                    value: routeViewModel.isRouteStarted ? "Active" : "Not Started",
                    icon: "location.circle.fill",
                    color: routeViewModel.isRouteStarted ? .green : .gray
                )

                MetricCard(
                    title: "Current Speed",
                    value: "\(Int(routeViewModel.currentSpeed)) mph",
                    icon: "speedometer",
                    color: .blue
                )

                MetricCard(
                    title: "Distance Today",
                    value: String(format: "%.1f mi", routeViewModel.totalDistanceTraveled),
                    icon: "location.north.line",
                    color: .orange
                )

                MetricCard(
                    title: "Next Job ETA",
                    value: formatTimeInterval(routeViewModel.estimatedTimeToNextJob),
                    icon: "clock.circle",
                    color: .purple
                )
            }

            // Weather Banner
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.cyan)
                VStack(alignment: .leading) {
                    Text("Weather Conditions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(routeViewModel.weatherConditions)
                        .font(.body)
                        .fontWeight(.medium)
                }
                Spacer()
            }
            .padding()
            .background(Color.cyan.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

struct DemoScenarioControls: View {
    @ObservedObject var routeViewModel: RouteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "theatermasks")
                    .foregroundColor(.purple)
                Text("Demo Scenarios")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(spacing: 8) {
                ScenarioButton(
                    title: "Standard Route",
                    description: "Normal day with mixed residential & commercial jobs",
                    icon: "house.circle",
                    color: .blue
                ) {
                    routeViewModel.loadDemoData()
                }

                ScenarioButton(
                    title: "Emergency Response",
                    description: "High-priority emergency calls requiring immediate attention",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                ) {
                    routeViewModel.loadEmergencyScenario()
                }

                ScenarioButton(
                    title: "Offline Mode",
                    description: "Simulate working without internet connection",
                    icon: "wifi.slash",
                    color: .gray
                ) {
                    routeViewModel.isOnline.toggle()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ScenarioButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

struct JobProgressionView: View {
    @ObservedObject var routeViewModel: RouteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                Text("Job Progression")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            // Progress Overview
            VStack(spacing: 8) {
                HStack {
                    Text("Route Progress")
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(routeViewModel.completionPercentage * 100))%")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                ProgressView(value: routeViewModel.completionPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))

                HStack {
                    JobStatusPill(
                        count: routeViewModel.completedJobsCount,
                        status: "Completed",
                        color: .green
                    )

                    JobStatusPill(
                        count: routeViewModel.jobs.filter { $0.status == .inProgress }.count,
                        status: "In Progress",
                        color: .blue
                    )

                    JobStatusPill(
                        count: routeViewModel.remainingJobsCount,
                        status: "Pending",
                        color: .orange
                    )
                }
            }

            // Job Simulation Controls
            if routeViewModel.demoMode {
                HStack {
                    Button("Auto-Progress Jobs") {
                        routeViewModel.progressDemoJobs()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)

                    Spacer()

                    Button(routeViewModel.isRouteStarted ? "End Route" : "Start Route") {
                        if routeViewModel.isRouteStarted {
                            routeViewModel.endRoute()
                        } else {
                            routeViewModel.startRoute()
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(routeViewModel.isRouteStarted ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundColor(routeViewModel.isRouteStarted ? .red : .green)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct JobStatusPill: View {
    let count: Int
    let status: String
    let color: Color

    var body: some View {
        VStack {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct DemoControlPanel_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            DemoControlPanel(routeViewModel: RouteViewModel())
                .padding()
        }
    }
}