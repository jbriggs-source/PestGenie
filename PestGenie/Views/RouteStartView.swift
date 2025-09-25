import SwiftUI

struct RouteStartView: View {
    @ObservedObject var routeViewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingDemoOptions = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Start Your Route")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Ready to begin today's pest control services?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Route Summary Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "map.circle.fill")
                                .foregroundColor(.green)
                            Text("Today's Route Summary")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        VStack(spacing: 12) {
                            RouteMetricRow(
                                icon: "list.bullet.clipboard",
                                title: "Total Jobs",
                                value: "\(routeViewModel.jobs.count)",
                                color: .blue
                            )

                            RouteMetricRow(
                                icon: "clock.circle",
                                title: "Estimated Duration",
                                value: estimatedDuration,
                                color: .orange
                            )

                            RouteMetricRow(
                                icon: "location.north.circle",
                                title: "Total Distance",
                                value: estimatedDistance,
                                color: .green
                            )

                            RouteMetricRow(
                                icon: "thermometer.sun",
                                title: "Weather",
                                value: routeViewModel.weatherConditions,
                                color: .cyan
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Equipment Check Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .foregroundColor(.green)
                            Text("Pre-Route Checklist")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        EquipmentChecklistView()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Start Route Button
                    VStack(spacing: 12) {
                        Button(action: {
                            startRouteAction()
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                Text("Start Route")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(routeViewModel.isRouteStarted)

                        // Demo Controls
                        Button("Demo Options") {
                            showingDemoOptions = true
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Route Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Demo Options", isPresented: $showingDemoOptions) {
            Button("Load Demo Data") {
                routeViewModel.loadDemoData()
            }
            Button("Emergency Scenario") {
                routeViewModel.loadEmergencyScenario()
                startRouteAction()
            }
            Button("Toggle Demo Mode") {
                routeViewModel.toggleDemoMode()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose a demo scenario to showcase PestGenie's capabilities")
        }
    }

    private var estimatedDuration: String {
        let hours = max(4, routeViewModel.jobs.count / 2)
        return "\(hours)h estimated"
    }

    private var estimatedDistance: String {
        let miles = max(15, routeViewModel.jobs.count * 3)
        return "\(miles) miles"
    }

    private func startRouteAction() {
        routeViewModel.startRoute()
        dismiss()
    }
}

struct RouteMetricRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct EquipmentChecklistView: View {
    @State private var checklistItems = [
        ChecklistItem(title: "Spray Equipment", isChecked: true),
        ChecklistItem(title: "Safety Gear (PPE)", isChecked: true),
        ChecklistItem(title: "Chemical Inventory", isChecked: false),
        ChecklistItem(title: "Documentation Forms", isChecked: true),
        ChecklistItem(title: "Emergency Contacts", isChecked: true),
        ChecklistItem(title: "Vehicle Inspection", isChecked: false)
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(checklistItems.indices, id: \.self) { index in
                HStack {
                    Button(action: {
                        checklistItems[index].isChecked.toggle()
                    }) {
                        Image(systemName: checklistItems[index].isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(checklistItems[index].isChecked ? .green : .gray)
                            .font(.title3)
                    }

                    Text(checklistItems[index].title)
                        .font(.body)
                        .foregroundColor(checklistItems[index].isChecked ? .primary : .secondary)

                    Spacer()
                }
            }
        }
    }
}

struct ChecklistItem {
    let title: String
    var isChecked: Bool
}

struct RouteStartView_Previews: PreviewProvider {
    static var previews: some View {
        RouteStartView(routeViewModel: RouteViewModel())
    }
}