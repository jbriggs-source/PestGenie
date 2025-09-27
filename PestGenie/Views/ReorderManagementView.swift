import SwiftUI

/// View for managing chemical reorder recommendations
struct ReorderManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var routeViewModel: RouteViewModel

    @State private var showingOrderConfirmation = false
    @State private var selectedRecommendations: Set<UUID> = []

    var reorderRecommendations: [ReorderRecommendation] {
        routeViewModel.getReorderRecommendations()
    }

    var lowStockChemicals: [Chemical] {
        routeViewModel.getLowStockChemicals()
    }

    var expiringChemicals: [Chemical] {
        routeViewModel.getExpiringChemicals()
    }

    var body: some View {
        NavigationView {
            List {
                if !reorderRecommendations.isEmpty {
                    Section {
                        ForEach(reorderRecommendations) { recommendation in
                            ReorderRecommendationRow(
                                recommendation: recommendation,
                                isSelected: selectedRecommendations.contains(recommendation.id)
                            ) {
                                toggleSelection(for: recommendation.id)
                            }
                        }
                    } header: {
                        Text("Reorder Recommendations")
                    } footer: {
                        Text("Based on recent usage patterns and current stock levels")
                    }
                }

                if !lowStockChemicals.isEmpty {
                    Section("Low Stock Alerts") {
                        ForEach(lowStockChemicals) { chemical in
                            ChemicalStockRow(chemical: chemical, alertType: .lowStock)
                        }
                    }
                }

                if !expiringChemicals.isEmpty {
                    Section("Expiration Alerts") {
                        ForEach(expiringChemicals) { chemical in
                            ChemicalStockRow(chemical: chemical, alertType: .expiring)
                        }
                    }
                }

                if reorderRecommendations.isEmpty && lowStockChemicals.isEmpty && expiringChemicals.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)

                            Text("All Stock Levels Good")
                                .font(.headline)

                            Text("No immediate reorders needed. All chemicals are adequately stocked and within expiration dates.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
            }
            .navigationTitle("Reorder Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if !selectedRecommendations.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Order Selected (\(selectedRecommendations.count))") {
                            showingOrderConfirmation = true
                        }
                    }
                }
            }
            .alert("Order Confirmation", isPresented: $showingOrderConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm Order") {
                    processOrders()
                }
            } message: {
                Text("This will generate order requests for \(selectedRecommendations.count) chemicals. Your supervisor will be notified.")
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedRecommendations.contains(id) {
            selectedRecommendations.remove(id)
        } else {
            selectedRecommendations.insert(id)
        }
    }

    private func processOrders() {
        // In production, this would integrate with ordering system
        let orderedChemicals = reorderRecommendations
            .filter { selectedRecommendations.contains($0.id) }
            .map { $0.chemical.name }

        print("Processing orders for: \(orderedChemicals.joined(separator: ", "))")
        selectedRecommendations.removeAll()
        dismiss()
    }
}

struct ReorderRecommendationRow: View {
    let recommendation: ReorderRecommendation
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.chemical.name)
                    .font(.headline)

                Text(recommendation.chemical.activeIngredient)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    PriorityBadge(priority: recommendation.priority)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Current: \(recommendation.chemical.quantityFormatted)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Recommended: \(String(format: "%.1f %@", recommendation.recommendedQuantity, recommendation.chemical.unitOfMeasure))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct ChemicalStockRow: View {
    let chemical: Chemical
    let alertType: AlertType

    enum AlertType {
        case lowStock, expiring

        var icon: String {
            switch self {
            case .lowStock: return "exclamationmark.triangle.fill"
            case .expiring: return "clock.badge.exclamationmark.fill"
            }
        }

        var color: Color {
            switch self {
            case .lowStock: return .orange
            case .expiring: return .red
            }
        }
    }

    var body: some View {
        HStack {
            Image(systemName: alertType.icon)
                .foregroundColor(alertType.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(chemical.name)
                    .font(.headline)

                if alertType == .lowStock {
                    Text("Low stock: \(chemical.quantityFormatted)")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    if chemical.isExpired {
                        Text("EXPIRED: \(chemical.expirationDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Expires: \(chemical.expirationDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(chemical.quantityFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if chemical.isExpired {
                    Text("EXPIRED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
            }
        }
    }
}

struct PriorityBadge: View {
    let priority: ReorderRecommendation.Priority

    var body: some View {
        Text(priority.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(priority.color))
            .cornerRadius(4)
    }
}

extension Color {
    init(_ colorName: String) {
        switch colorName {
        case "blue": self = .blue
        case "yellow": self = .yellow
        case "orange": self = .orange
        case "red": self = .red
        default: self = .gray
        }
    }
}

#Preview {
    ReorderManagementView(routeViewModel: RouteViewModel())
}