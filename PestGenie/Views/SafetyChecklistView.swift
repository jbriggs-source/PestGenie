import SwiftUI
import PhotosUI

struct SafetyChecklistView: View {
    @StateObject private var checklistManager = SafetyChecklistManager()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: SafetyChecklistCategory = .personalProtectiveEquipment
    @State private var showingViolationReport = false
    @State private var selectedViolation: SafetyViolationReport?
    @State private var showingCompletionAlert = false
    @State private var supervisorSignature: String = ""
    @State private var finalNotes: String = ""

    let technicianId: String

    init(technicianId: String) {
        self.technicianId = technicianId
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with progress
                checklistHeader

                // Category selector
                categorySelector

                // Checklist content
                checklistContent

                // Bottom actions
                bottomActions
            }
            .navigationTitle("Safety Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedViolation) { violation in
            ViolationDetailView(violation: violation, checklistManager: checklistManager)
        }
        .alert("Complete Safety Checklist", isPresented: $showingCompletionAlert) {
            TextField("Supervisor Signature (if required)", text: $supervisorSignature)
            TextField("Additional Notes", text: $finalNotes)

            Button("Complete") {
                checklistManager.finalizeChecklist(supervisorSignature: supervisorSignature.isEmpty ? nil : supervisorSignature, notes: finalNotes)
                dismiss()
            }
            .disabled(!canCompleteChecklist())

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Review all items and finalize the safety checklist. Supervisor signature may be required for violations.")
        }
        .onAppear {
            if checklistManager.currentChecklist == nil {
                let _ = checklistManager.startNewChecklist(for: technicianId)
            }
        }
    }

    // MARK: - Header

    private var checklistHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Checklist")
                        .font(.headline)
                        .fontWeight(.bold)

                    if let checklist = checklistManager.currentChecklist {
                        Text("Started: \(checklist.startedAt, style: .time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(getCompletionPercentage())%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(getCompletionColor())

                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            ProgressView(value: Double(getCompletionPercentage()), total: 100.0)
                .tint(getCompletionColor())

            // Compliance score
            if checklistManager.getComplianceScore() > 0 {
                HStack {
                    Text("Compliance Score:")
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(Int(checklistManager.getComplianceScore() * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(getComplianceColor())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Category Selector

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SafetyChecklistCategory.allCases, id: \.self) { category in
                    CategoryTab(
                        category: category,
                        isSelected: selectedCategory == category,
                        completedCount: getCompletedItemsCount(for: category),
                        totalCount: getTotalItemsCount(for: category)
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Checklist Content

    private var checklistContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let checklist = checklistManager.currentChecklist {
                    let categoryItems = checklist.items.filter { $0.category == selectedCategory }

                    ForEach(categoryItems) { item in
                        SafetyChecklistItemRow(
                            item: item,
                            completion: checklist.completedItems.first { $0.itemId == item.id },
                            onComplete: { isCompliant, photos, notes in
                                checklistManager.completeChecklistItem(item.id, isCompliant: isCompliant, photos: photos, notes: notes)
                            }
                        )
                    }

                    // Category violations
                    let categoryViolations = checklist.violations.filter { $0.category == selectedCategory }
                    if !categoryViolations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category Violations")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.red)

                            ForEach(categoryViolations) { violation in
                                ViolationSummaryCard(violation: violation) {
                                    selectedViolation = violation
                                }
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 12) {
            // Validation status
            let validation = checklistManager.validateChecklistCompletion()
            if !validation.isValid {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Checklist Issues")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    ForEach(validation.errors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Complete checklist button
            Button(action: {
                showingCompletionAlert = true
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Safety Checklist")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canCompleteChecklist() ? Color.green : Color.gray)
                .cornerRadius(10)
            }
            .disabled(!canCompleteChecklist())
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Helper Methods

    private func getCompletionPercentage() -> Int {
        guard let checklist = checklistManager.currentChecklist else { return 0 }

        let totalItems = checklist.items.count
        guard totalItems > 0 else { return 0 }

        let completedItems = checklist.completedItems.count
        return Int((Double(completedItems) / Double(totalItems)) * 100)
    }

    private func getCompletionColor() -> Color {
        let percentage = getCompletionPercentage()
        if percentage >= 100 { return .green }
        if percentage >= 75 { return .blue }
        if percentage >= 50 { return .orange }
        return .red
    }

    private func getComplianceColor() -> Color {
        let score = checklistManager.getComplianceScore()
        if score >= 0.95 { return .green }
        if score >= 0.85 { return .orange }
        return .red
    }

    private func getCompletedItemsCount(for category: SafetyChecklistCategory) -> Int {
        guard let checklist = checklistManager.currentChecklist else { return 0 }

        let categoryItemIds = checklist.items.filter { $0.category == category }.map { $0.id }
        return checklist.completedItems.filter { categoryItemIds.contains($0.itemId) }.count
    }

    private func getTotalItemsCount(for category: SafetyChecklistCategory) -> Int {
        guard let checklist = checklistManager.currentChecklist else { return 0 }
        return checklist.items.filter { $0.category == category }.count
    }

    private func canCompleteChecklist() -> Bool {
        guard let checklist = checklistManager.currentChecklist else { return false }

        // Must have completed all required items
        let requiredItems = checklist.items.filter { $0.isRequired }
        let completedRequiredItems = requiredItems.filter { item in
            checklist.completedItems.contains { $0.itemId == item.id }
        }

        return completedRequiredItems.count == requiredItems.count
    }
}

// MARK: - Category Tab

struct CategoryTab: View {
    let category: SafetyChecklistCategory
    let isSelected: Bool
    let completedCount: Int
    let totalCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: category.icon)
                        .font(.caption)

                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(isSelected ? .bold : .medium)
                }

                // Progress indicator
                Text("\(completedCount)/\(totalCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Rectangle()
                    .fill(isSelected ? Color(category.color) : Color.clear)
                    .frame(height: 2)
            }
            .foregroundColor(isSelected ? Color(category.color) : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Safety Checklist Item Row

struct SafetyChecklistItemRow: View {
    let item: SafetyChecklistItem
    let completion: SafetyChecklistCompletion?
    let onComplete: (Bool, [Data], String) -> Void

    @State private var isExpanded = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var notes: String = ""
    @State private var tempCompliance: Bool? = nil

    var isCompleted: Bool {
        completion != nil
    }

    var isCompliant: Bool {
        completion?.isCompliant ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main item row
            HStack(spacing: 12) {
                // Status indicator
                Button(action: {
                    if !isCompleted {
                        isExpanded.toggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(getStatusColor())
                            .frame(width: 24, height: 24)

                        Image(systemName: getStatusIcon())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .disabled(isCompleted)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isCompleted ? .secondary : .primary)

                        if item.isRequired {
                            Text("REQUIRED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }

                        Spacer()

                        // Priority indicator
                        SafetyPriorityBadge(priority: item.priority)
                    }

                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                if !isCompleted {
                    Button(action: {
                        isExpanded.toggle()
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Expanded content for incomplete items
            if isExpanded && !isCompleted {
                VStack(alignment: .leading, spacing: 12) {
                    // Compliance selection
                    HStack(spacing: 16) {
                        Text("Item Status:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Button(action: {
                            tempCompliance = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tempCompliance == true ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(.green)
                                Text("Compliant")
                                    .font(.subheadline)
                            }
                        }

                        Button(action: {
                            tempCompliance = false
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tempCompliance == false ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(.red)
                                Text("Non-Compliant")
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Photo attachment
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Photos:")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 5,
                                matching: .images
                            ) {
                                HStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                    Text("Add Photos")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }

                        if !photoData.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(0..<photoData.count, id: \.self) { index in
                                        if let uiImage = UIImage(data: photoData[index]) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 60, height: 60)
                                                .cornerRadius(8)
                                                .clipped()
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Additional notes or observations...", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...4)
                    }

                    // Complete button
                    Button(action: {
                        guard let compliance = tempCompliance else { return }
                        onComplete(compliance, photoData, notes)
                        isExpanded = false
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete Item")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(tempCompliance != nil ? Color.blue : Color.gray)
                        .cornerRadius(8)
                    }
                    .disabled(tempCompliance == nil)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Completion details for completed items
            if let completion = completion {
                CompletionDetailsView(completion: completion)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onChange(of: selectedPhotos) { _ in
            Task {
                photoData = []
                for item in selectedPhotos {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        photoData.append(data)
                    }
                }
            }
        }
    }

    private func getStatusColor() -> Color {
        if isCompleted {
            return isCompliant ? .green : .red
        }
        return .gray
    }

    private func getStatusIcon() -> String {
        if isCompleted {
            return isCompliant ? "checkmark" : "xmark"
        }
        return "circle"
    }
}

// MARK: - Priority Badge

struct SafetyPriorityBadge: View {
    let priority: SafetyChecklistPriority

    var body: some View {
        Text(priority.rawValue.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(priority.color))
            .cornerRadius(4)
    }
}

// MARK: - Completion Details View

struct CompletionDetailsView: View {
    let completion: SafetyChecklistCompletion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Completed:")
                    .font(.caption)
                    .fontWeight(.medium)

                Text(completion.completedAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(completion.isCompliant ? "COMPLIANT" : "VIOLATION")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(completion.isCompliant ? Color.green : Color.red)
                    .cornerRadius(4)
            }

            if !completion.notes.isEmpty {
                Text(completion.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            if !completion.photos.isEmpty {
                Text("\(completion.photos.count) photo(s) attached")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(completion.isCompliant ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Violation Summary Card

struct ViolationSummaryCard: View {
    let violation: SafetyViolationReport
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(violation.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)

                    Text(violation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(violation.severity.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(violation.severity.color))
                        .cornerRadius(4)

                    if violation.isResolved {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Violation Detail View

struct ViolationDetailView: View {
    let violation: SafetyViolationReport
    @ObservedObject var checklistManager: SafetyChecklistManager
    @Environment(\.dismiss) private var dismiss

    @State private var resolutionNotes: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Violation header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title)
                                .foregroundColor(.red)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(violation.title)
                                    .font(.headline)
                                    .fontWeight(.bold)

                                Text(violation.severity.rawValue.capitalized + " Severity")
                                    .font(.subheadline)
                                    .foregroundColor(Color(violation.severity.color))
                            }

                            Spacer()
                        }

                        Text(violation.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Violation Details")
                            .font(.headline)
                            .fontWeight(.bold)

                        VStack(spacing: 8) {
                            SafetyDetailRow(title: "Category", value: violation.category.displayName)
                            SafetyDetailRow(title: "Reported", value: violation.reportedAt.formatted())
                            SafetyDetailRow(title: "Status", value: violation.isResolved ? "Resolved" : "Active")

                            if violation.isResolved, let resolvedAt = violation.resolvedAt {
                                SafetyDetailRow(title: "Resolved", value: resolvedAt.formatted())
                            }
                        }
                    }

                    // Photos
                    if !violation.photos.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Evidence Photos")
                                .font(.headline)
                                .fontWeight(.bold)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<violation.photos.count, id: \.self) { index in
                                        if let uiImage = UIImage(data: violation.photos[index]) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .cornerRadius(8)
                                                .clipped()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Notes
                    if !violation.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                                .fontWeight(.bold)

                            Text(violation.notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Resolution section
                    if !violation.isResolved {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resolve Violation")
                                .font(.headline)
                                .fontWeight(.bold)

                            TextField("Resolution notes...", text: $resolutionNotes, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)

                            Button(action: {
                                checklistManager.resolveViolation(violation.id, notes: resolutionNotes)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Mark as Resolved")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                            }
                            .disabled(resolutionNotes.isEmpty)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Violation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row

struct SafetyDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    SafetyChecklistView(technicianId: "tech123")
}