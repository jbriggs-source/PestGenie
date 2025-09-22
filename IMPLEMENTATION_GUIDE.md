# PestGenie Implementation Guide
## How to Move Forward with Field Technician Features

*Last Updated: December 2024*
*Actionable Implementation Steps*

## 🎯 **Phase 1 Implementation Priority**

### **Week 1-2: Chemical Management System**

#### **Step 1: Extend Core Data Model**
```swift
// File: PestGenie/Models.swift
// Add these entities to your existing model:

@objc(ChemicalEntity)
public class ChemicalEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var epaNumber: String
    @NSManaged public var productName: String
    @NSManaged public var manufacturer: String
    @NSManaged public var activeIngredient: String
    @NSManaged public var concentration: Double
    @NSManaged public var expirationDate: Date
    @NSManaged public var quantityOnHand: Double
    @NSManaged public var unitOfMeasure: String
    @NSManaged public var msdsUrl: String?
    @NSManaged public var syncStatus: String
    @NSManaged public var lastModified: Date
    @NSManaged public var serverId: String?
    @NSManaged public var treatments: Set<ChemicalTreatmentEntity>
}

@objc(ChemicalTreatmentEntity)
public class ChemicalTreatmentEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var chemicalUsed: ChemicalEntity
    @NSManaged public var dosageAmount: Double
    @NSManaged public var dilutionRatio: Double
    @NSManaged public var applicationMethod: String
    @NSManaged public var targetPest: String
    @NSManaged public var applicationDate: Date
    @NSManaged public var job: JobEntity
    @NSManaged public var syncStatus: String
    @NSManaged public var lastModified: Date
    @NSManaged public var serverId: String?
}
```

#### **Step 2: Add SDUI Components**
```swift
// File: PestGenie/SDUI.swift
// Add to SDUIComponentType enum:

case chemicalSelector = "chemical_selector"
case dosageCalculator = "dosage_calculator"
case dilutionMixer = "dilution_mixer"
case chemicalInventory = "chemical_inventory"
```

#### **Step 3: Create Component Renderers**
```swift
// File: PestGenie/SDUI+ChemicalComponents.swift
// New file to create:

import SwiftUI

struct ChemicalSelectorRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        return AnyView(ChemicalSelectorView(
            selectedChemicalId: component.valueKey ?? "",
            onChemicalSelected: { chemicalId in
                // Store selection using existing input system
                let contextKey = SDUIDataResolver.makeContextKey(
                    key: component.valueKey ?? "",
                    job: context.currentJob
                )
                context.routeViewModel.setTextValue(forKey: contextKey, value: chemicalId)
            }
        ))
    }
}

struct ChemicalSelectorView: View {
    let selectedChemicalId: String
    let onChemicalSelected: (String) -> Void

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChemicalEntity.productName, ascending: true)]
    ) var chemicals: FetchedResults<ChemicalEntity>

    var body: some View {
        VStack(alignment: .leading) {
            Text("Select Chemical")
                .font(.headline)

            Picker("Chemical", selection: .constant(selectedChemicalId)) {
                ForEach(chemicals, id: \.id) { chemical in
                    VStack(alignment: .leading) {
                        Text(chemical.productName)
                            .font(.body)
                        Text("EPA: \(chemical.epaNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(chemical.id.uuidString)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: selectedChemicalId) { newValue in
                onChemicalSelected(newValue)
            }
        }
    }
}
```

### **Week 3-4: Equipment Management**

#### **Step 1: Equipment Data Model**
```swift
// Add to Models.swift:

@objc(EquipmentEntity)
public class EquipmentEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var equipmentType: String // "sprayer", "backpack", "probe"
    @NSManaged public var manufacturer: String
    @NSManaged public var model: String
    @NSManaged public var serialNumber: String
    @NSManaged public var qrCode: String?
    @NSManaged public var lastCalibrationDate: Date?
    @NSManaged public var nextCalibrationDue: Date?
    @NSManaged public var maintenanceNotes: String?
    @NSManaged public var syncStatus: String
    @NSManaged public var lastModified: Date
    @NSManaged public var serverId: String?
    @NSManaged public var inspections: Set<EquipmentInspectionEntity>
}

@objc(EquipmentInspectionEntity)
public class EquipmentInspectionEntity: NSManagedObject, SyncableEntity {
    @NSManaged public var id: UUID
    @NSManaged public var equipment: EquipmentEntity
    @NSManaged public var inspectionDate: Date
    @NSManaged public var inspectedBy: String
    @NSManaged public var pressureCheck: Bool
    @NSManaged public var leakCheck: Bool
    @NSManaged public var calibrationCheck: Bool
    @NSManaged public var overallCondition: String
    @NSManaged public var notes: String?
    @NSManaged public var job: JobEntity?
    @NSManaged public var syncStatus: String
    @NSManaged public var lastModified: Date
    @NSManaged public var serverId: String?
}
```

#### **Step 2: Equipment SDUI Components**
```swift
// Add to SDUIComponentType:
case equipmentInspector = "equipment_inspector"
case equipmentSelector = "equipment_selector"
case qrScanner = "qr_scanner"
```

## 🛠️ **Development Workflow**

### **Daily Development Process**
```bash
# 1. Start development session
cd /Users/jbriggs/StudioProjects/PestGenie
git pull origin main

# 2. Create feature branch
git checkout -b feature/chemical-management

# 3. Open in Xcode
open PestGenie.xcodeproj

# 4. Make changes following the roadmap

# 5. Test changes
# Build and run (⌘+R)
# Run tests (⌘+U)

# 6. Commit progress
git add .
git commit -m "Add chemical management core data model"

# 7. Push to feature branch
git push origin feature/chemical-management
```

### **Testing Strategy**
```swift
// Create tests for each new feature:
// File: PestGenieTests/ChemicalManagementTests.swift

import XCTest
@testable import PestGenie

final class ChemicalManagementTests: XCTestCase {

    func testChemicalEntityCreation() throws {
        let context = PersistenceController(inMemory: true).container.viewContext

        let chemical = ChemicalEntity(context: context)
        chemical.id = UUID()
        chemical.productName = "Test Pesticide"
        chemical.epaNumber = "EPA-12345"
        chemical.concentration = 25.0

        try context.save()

        XCTAssertEqual(chemical.productName, "Test Pesticide")
        XCTAssertEqual(chemical.epaNumber, "EPA-12345")
    }

    func testDilutionCalculation() throws {
        // Test chemical dilution math
        let targetVolume: Double = 100.0 // liters
        let productConcentration: Double = 25.0 // percent
        let desiredConcentration: Double = 2.5 // percent

        let dilutionRatio = productConcentration / desiredConcentration
        let productAmount = targetVolume / dilutionRatio
        let waterAmount = targetVolume - productAmount

        XCTAssertEqual(dilutionRatio, 10.0)
        XCTAssertEqual(productAmount, 10.0)
        XCTAssertEqual(waterAmount, 90.0)
    }
}
```

## 📋 **Implementation Checklist**

### **Phase 1.1: Chemical Management (Weeks 1-2)**
- [ ] Extend Core Data model with Chemical entities
- [ ] Add chemical_selector SDUI component
- [ ] Add dosage_calculator SDUI component
- [ ] Create chemical inventory management views
- [ ] Implement chemical expiration alerts
- [ ] Add dilution ratio calculator
- [ ] Test offline chemical logging
- [ ] Test sync with existing infrastructure
- [ ] Add unit tests for chemical calculations
- [ ] Create chemical management JSON schemas

### **Phase 1.2: Equipment Management (Weeks 3-4)**
- [ ] Extend Core Data model with Equipment entities
- [ ] Add equipment_inspector SDUI component
- [ ] Add QR code scanning for equipment
- [ ] Create digital inspection checklists
- [ ] Implement maintenance scheduling
- [ ] Add equipment calibration tracking
- [ ] Test equipment offline workflows
- [ ] Add equipment performance metrics
- [ ] Create equipment test suite
- [ ] Design equipment JSON configurations

### **Phase 1.3: Weather Integration (Week 5)**
- [ ] Add weather API integration
- [ ] Create weather_dashboard SDUI component
- [ ] Implement weather-based treatment alerts
- [ ] Add wind speed/direction monitoring
- [ ] Create precipitation warnings
- [ ] Test weather data caching
- [ ] Add weather-based notifications
- [ ] Integrate with existing location services

## 🔧 **Tools & Resources Needed**

### **Development Tools**
```
✅ Already Available:
- Xcode (latest version)
- iOS Simulator
- Git version control
- Existing test framework
- Core Data modeling tools

🆕 Additional Tools Needed:
- Weather API key (OpenWeatherMap or similar)
- QR code scanning library (AVFoundation)
- Chemical database (EPA registration numbers)
- Equipment manufacturer databases
```

### **Third-Party Integrations**
```
Priority 1 (Immediate):
- Weather API (OpenWeatherMap, WeatherKit)
- EPA chemical database integration
- QR/Barcode scanning capabilities

Priority 2 (Later phases):
- Chemical supplier APIs
- Equipment manufacturer APIs
- Customer communication platforms
```

## 📊 **Success Metrics & KPIs**

### **Development Metrics**
```
Technical Goals:
- App Store rating: Maintain 4.5+ stars
- Crash rate: < 0.1%
- Test coverage: > 80%
- Build time: < 5 minutes
- Offline functionality: 99.9% reliability
```

### **Business Metrics**
```
User Adoption:
- Daily active users increase: 25%
- Feature adoption rate: > 60%
- Customer satisfaction: 4.5+ rating

Operational Efficiency:
- Chemical waste reduction: 15-25%
- Equipment downtime reduction: 20%
- Route completion time: 10% improvement
```

## 🆘 **Getting Help & Support**

### **Claude Code Sessions**
```
For future development sessions:
1. Open this project in Claude Code
2. Reference FIELD_TECHNICIAN_ROADMAP.md for strategic context
3. Reference ENTERPRISE_ARCHITECTURE_ANALYSIS.md for technical patterns
4. Use iOS SwiftUI Expert agent for code reviews
```

### **Development Questions**
```
Common scenarios where you'll need guidance:
- SDUI component implementation
- Core Data model extensions
- Sync manager modifications
- Performance optimization
- Testing strategy refinement
```

## 🎯 **Next Immediate Actions**

### **This Week (Week 1)**
1. **Review Roadmap**: Read through both markdown files completely
2. **Set Up Environment**: Ensure Xcode and git are ready
3. **Create Feature Branch**: `git checkout -b feature/chemical-management`
4. **Start Core Data**: Begin with ChemicalEntity implementation
5. **Test Foundation**: Ensure existing tests still pass

### **Next Week (Week 2)**
1. **SDUI Components**: Implement chemical_selector component
2. **Test Integration**: Verify offline functionality works
3. **User Testing**: Get feedback from a pest control professional
4. **Iteration**: Refine based on real-world feedback
5. **Documentation**: Update implementation progress

---

**Ready to start building! The roadmap is your strategic guide, the architecture analysis is your technical blueprint, and this implementation guide gives you the step-by-step actions to begin immediately.**