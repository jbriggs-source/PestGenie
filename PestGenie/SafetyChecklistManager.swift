import Foundation
import SwiftUI
import CoreLocation

class SafetyChecklistManager: ObservableObject {
    @Published var currentChecklist: SafetyChecklistRecord?
    @Published var checklistHistory: [SafetyChecklistRecord] = []
    @Published var violations: [SafetyViolationReport] = []

    private let userDefaults = UserDefaults.standard
    private let checklistHistoryKey = "safety_checklist_history"
    private let violationsKey = "safety_violations"

    init() {
        loadChecklistHistory()
        loadViolations()
    }

    // MARK: - Checklist Creation and Management

    func startNewChecklist(for technicianId: String) -> SafetyChecklistRecord {
        let checklistId = UUID()

        let allItems = getAllSafetyChecklistItems()
        let checklist = SafetyChecklistRecord(
            id: checklistId,
            technicianId: technicianId,
            startedAt: Date(),
            items: allItems,
            completedItems: [],
            violations: [],
            isCompleted: false,
            completedAt: nil,
            supervisorSignature: nil,
            notes: ""
        )

        currentChecklist = checklist
        return checklist
    }

    func completeChecklistItem(_ itemId: UUID, isCompliant: Bool, photos: [Data] = [], notes: String = "") {
        guard var checklist = currentChecklist else { return }

        let completion = SafetyChecklistCompletion(
            itemId: itemId,
            isCompliant: isCompliant,
            completedAt: Date(),
            photos: photos,
            notes: notes
        )

        checklist.completedItems.append(completion)

        // Check for violations
        if !isCompliant {
            if let item = checklist.items.first(where: { $0.id == itemId }) {
                reportViolation(checklistId: checklist.id, item: item, photos: photos, notes: notes)
            }
        }

        currentChecklist = checklist
        saveCurrentChecklist()
    }

    func finalizeChecklist(supervisorSignature: String?, notes: String = "") {
        guard var checklist = currentChecklist else { return }

        checklist.isCompleted = true
        checklist.completedAt = Date()
        checklist.supervisorSignature = supervisorSignature
        checklist.notes = notes

        // Add to history
        checklistHistory.insert(checklist, at: 0)

        // Keep only last 100 checklists
        if checklistHistory.count > 100 {
            checklistHistory = Array(checklistHistory.prefix(100))
        }

        saveChecklistHistory()
        currentChecklist = nil
    }

    // MARK: - Validation

    func validateChecklistCompletion() -> ChecklistValidationResult {
        guard let checklist = currentChecklist else {
            return ChecklistValidationResult(isValid: false, errors: ["No active checklist found"])
        }

        var errors: [String] = []
        let totalItems = checklist.items.count
        let completedItems = checklist.completedItems.count

        // Check completion percentage
        let completionPercentage = Double(completedItems) / Double(totalItems)
        if completionPercentage < 1.0 {
            errors.append("Checklist is not 100% complete (\(Int(completionPercentage * 100))% completed)")
        }

        // Check for critical violations
        let criticalViolations = checklist.violations.filter { $0.severity == .critical }
        if !criticalViolations.isEmpty {
            errors.append("Critical safety violations must be resolved before proceeding")
        }

        // Check for required supervisor signature on violations
        let highPriorityViolations = checklist.violations.filter { $0.severity == .high || $0.severity == .critical }
        if !highPriorityViolations.isEmpty && checklist.supervisorSignature == nil {
            errors.append("Supervisor signature required for high/critical violations")
        }

        return ChecklistValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    func getComplianceScore() -> Double {
        guard let checklist = currentChecklist else { return 0.0 }

        let totalItems = checklist.completedItems.count
        guard totalItems > 0 else { return 0.0 }

        let compliantItems = checklist.completedItems.filter { $0.isCompliant }.count
        return Double(compliantItems) / Double(totalItems)
    }

    // MARK: - Violation Management

    private func reportViolation(checklistId: UUID, item: SafetyChecklistItem, photos: [Data], notes: String) {
        let violation = SafetyViolationReport(
            id: UUID(),
            checklistId: checklistId,
            itemId: item.id,
            category: item.category,
            severity: item.priority == .critical ? .critical : (item.priority == .high ? .high : .medium),
            title: "Safety Violation: \(item.title)",
            description: "Non-compliance with: \(item.description)",
            reportedAt: Date(),
            photos: photos,
            notes: notes,
            isResolved: false,
            resolvedAt: nil,
            supervisorNotified: item.priority == .critical || item.priority == .high
        )

        violations.append(violation)

        // Add to current checklist violations
        if var checklist = currentChecklist {
            checklist.violations.append(violation)
            currentChecklist = checklist
        }

        saveViolations()

        // Auto-notify for critical violations
        if violation.severity == .critical {
            notifySupervisorOfCriticalViolation(violation)
        }
    }

    func resolveViolation(_ violationId: UUID, notes: String = "") {
        if let index = violations.firstIndex(where: { $0.id == violationId }) {
            violations[index].isResolved = true
            violations[index].resolvedAt = Date()
            violations[index].notes += "\nResolution: \(notes)"
            saveViolations()
        }

        // Update current checklist if applicable
        if var checklist = currentChecklist,
           let checklistIndex = checklist.violations.firstIndex(where: { $0.id == violationId }) {
            checklist.violations[checklistIndex].isResolved = true
            checklist.violations[checklistIndex].resolvedAt = Date()
            currentChecklist = checklist
        }
    }

    // MARK: - Data Persistence

    private func saveCurrentChecklist() {
        guard let checklist = currentChecklist else { return }
        do {
            let data = try JSONEncoder().encode(checklist)
            userDefaults.set(data, forKey: "current_safety_checklist")
        } catch {
            print("Failed to save current checklist: \(error)")
        }
    }

    private func saveChecklistHistory() {
        do {
            let data = try JSONEncoder().encode(checklistHistory)
            userDefaults.set(data, forKey: checklistHistoryKey)
        } catch {
            print("Failed to save checklist history: \(error)")
        }
    }

    private func loadChecklistHistory() {
        guard let data = userDefaults.data(forKey: checklistHistoryKey) else { return }
        do {
            checklistHistory = try JSONDecoder().decode([SafetyChecklistRecord].self, from: data)
        } catch {
            print("Failed to load checklist history: \(error)")
        }
    }

    private func saveViolations() {
        do {
            let data = try JSONEncoder().encode(violations)
            userDefaults.set(data, forKey: violationsKey)
        } catch {
            print("Failed to save violations: \(error)")
        }
    }

    private func loadViolations() {
        guard let data = userDefaults.data(forKey: violationsKey) else { return }
        do {
            violations = try JSONDecoder().decode([SafetyViolationReport].self, from: data)
        } catch {
            print("Failed to load violations: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func getAllSafetyChecklistItems() -> [SafetyChecklistItem] {
        var allItems: [SafetyChecklistItem] = []

        // PPE Items
        allItems.append(contentsOf: [
            SafetyChecklistItem(
                id: UUID(),
                category: .ppe,
                title: "Safety Glasses/Goggles",
                description: "Proper eye protection is worn and in good condition",
                priority: .high,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .ppe,
                title: "Respirator/Mask",
                description: "Appropriate respiratory protection for chemicals being used",
                priority: .critical,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .ppe,
                title: "Chemical-Resistant Gloves",
                description: "Proper gloves for chemical handling, no tears or degradation",
                priority: .high,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .ppe,
                title: "Protective Clothing",
                description: "Long sleeves, pants, and closed-toe shoes",
                priority: .medium,
                isRequired: true
            )
        ])

        // Chemical Safety Items
        allItems.append(contentsOf: [
            SafetyChecklistItem(
                id: UUID(),
                category: .chemicalSafety,
                title: "Chemical Labels Readable",
                description: "All chemical containers have legible labels",
                priority: .high,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .chemicalSafety,
                title: "SDS Sheets Available",
                description: "Safety Data Sheets accessible for all chemicals",
                priority: .high,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .chemicalSafety,
                title: "Chemical Storage Secure",
                description: "Chemicals properly stored and secured in vehicle",
                priority: .critical,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .chemicalSafety,
                title: "Spill Kit Available",
                description: "Emergency spill containment kit present and complete",
                priority: .medium,
                isRequired: true
            )
        ])

        // Equipment Safety Items
        allItems.append(contentsOf: [
            SafetyChecklistItem(
                id: UUID(),
                category: .equipmentSafety,
                title: "Sprayer Equipment Inspection",
                description: "No leaks, proper pressure, all connections secure",
                priority: .high,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .equipmentSafety,
                title: "Ladder Safety Check",
                description: "Ladder in good condition, proper setup and usage",
                priority: .high,
                isRequired: false
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .equipmentSafety,
                title: "Hand Tools Condition",
                description: "All tools in good working order and properly maintained",
                priority: .medium,
                isRequired: true
            )
        ])

        // Site Assessment Items
        allItems.append(contentsOf: [
            SafetyChecklistItem(
                id: UUID(),
                category: .siteAssessment,
                title: "Weather Conditions Check",
                description: "Wind speed, precipitation, and temperature suitable for application",
                priority: .high,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .siteAssessment,
                title: "Customer Safety Briefing",
                description: "Customer informed of treatment areas and safety precautions",
                priority: .medium,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .siteAssessment,
                title: "Pet/Wildlife Assessment",
                description: "No pets, beneficial insects, or wildlife in treatment area",
                priority: .high,
                isRequired: true
            )
        ])

        // Health/Medical Items
        allItems.append(contentsOf: [
            SafetyChecklistItem(
                id: UUID(),
                category: .healthMedical,
                title: "Technician Health Check",
                description: "Feeling well, no symptoms that would impair safety",
                priority: .medium,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .healthMedical,
                title: "First Aid Kit Available",
                description: "Complete first aid kit accessible in vehicle",
                priority: .medium,
                isRequired: true
            )
        ])

        // Regulatory Compliance Items
        allItems.append(contentsOf: [
            SafetyChecklistItem(
                id: UUID(),
                category: .regulatoryCompliance,
                title: "Applicator License Current",
                description: "Valid pesticide applicator license and certification",
                priority: .critical,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .regulatoryCompliance,
                title: "Application Records Ready",
                description: "Treatment records and documentation prepared",
                priority: .medium,
                isRequired: true
            )
        ])

        // Communication Items
        allItems.append(contentsOf: [
            SafetyChecklistItem(
                id: UUID(),
                category: .communication,
                title: "Emergency Contacts Available",
                description: "Emergency contact numbers accessible",
                priority: .medium,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .communication,
                title: "Dispatch Communication Test",
                description: "Radio/phone communication with dispatch confirmed",
                priority: .low,
                isRequired: false
            )
        ])

        // Vehicle/Transportation Items
        allItems.append(contentsOf: [
            SafetyChecklistItem(
                id: UUID(),
                category: .vehicleTransportation,
                title: "Vehicle Safety Inspection",
                description: "Tires, brakes, lights, and safety equipment checked",
                priority: .high,
                isRequired: true
            ),
            SafetyChecklistItem(
                id: UUID(),
                category: .vehicleTransportation,
                title: "Cargo Securement",
                description: "All equipment and chemicals properly secured for transport",
                priority: .high,
                isRequired: true
            )
        ])

        return allItems
    }

    private func notifySupervisorOfCriticalViolation(_ violation: SafetyViolationReport) {
        // In a real implementation, this would send push notifications or alerts
        print("CRITICAL VIOLATION ALERT: \(violation.title)")
        print("Immediate supervisor notification required")

        // Integration point for emergency system
        // Could trigger emergency protocols or automatic reporting
    }

    // MARK: - Statistics and Reporting

    func getComplianceStatistics(for period: DateInterval? = nil) -> SafetyComplianceStatistics {
        let relevantChecklists: [SafetyChecklistRecord]

        if let period = period {
            relevantChecklists = checklistHistory.filter { checklist in
                guard let completedAt = checklist.completedAt else { return false }
                return period.contains(completedAt)
            }
        } else {
            relevantChecklists = checklistHistory
        }

        let totalChecklists = relevantChecklists.count
        guard totalChecklists > 0 else {
            return SafetyComplianceStatistics(
                totalChecklists: 0,
                averageComplianceScore: 0.0,
                totalViolations: 0,
                criticalViolations: 0,
                resolvedViolations: 0,
                complianceRate: 0.0
            )
        }

        let totalViolations = relevantChecklists.flatMap { $0.violations }.count
        let criticalViolations = relevantChecklists.flatMap { $0.violations }.filter { $0.severity == .critical }.count
        let resolvedViolations = relevantChecklists.flatMap { $0.violations }.filter { $0.isResolved }.count

        let complianceScores = relevantChecklists.map { checklist in
            let completedItems = checklist.completedItems.count
            guard completedItems > 0 else { return 0.0 }
            let compliantItems = checklist.completedItems.filter { $0.isCompliant }.count
            return Double(compliantItems) / Double(completedItems)
        }

        let averageComplianceScore = complianceScores.isEmpty ? 0.0 : complianceScores.reduce(0, +) / Double(complianceScores.count)
        let complianceRate = Double(relevantChecklists.filter { $0.violations.isEmpty }.count) / Double(totalChecklists)

        return SafetyComplianceStatistics(
            totalChecklists: totalChecklists,
            averageComplianceScore: averageComplianceScore,
            totalViolations: totalViolations,
            criticalViolations: criticalViolations,
            resolvedViolations: resolvedViolations,
            complianceRate: complianceRate
        )
    }
}

// MARK: - Supporting Data Structures

struct ChecklistValidationResult {
    let isValid: Bool
    let errors: [String]
}

struct SafetyComplianceStatistics {
    let totalChecklists: Int
    let averageComplianceScore: Double
    let totalViolations: Int
    let criticalViolations: Int
    let resolvedViolations: Int
    let complianceRate: Double
}