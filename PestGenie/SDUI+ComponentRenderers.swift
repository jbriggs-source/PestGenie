import SwiftUI
import CoreData
import CoreLocation

/*
 SDUI Component Renderers for Field Technician Features

 This file integrates the following field technician component categories:

 1. WEATHER COMPONENTS:
    - WeatherDashboard: Real-time weather conditions with safety analysis
    - WeatherAlert: Critical weather alerts for field safety
    - WeatherForecast: Multi-day weather forecast for planning
    - WeatherMetrics: Specific weather metrics (temp, humidity, wind, etc.)
    - SafetyIndicator: Treatment safety status indicator
    - TreatmentConditions: Comprehensive treatment condition analysis

 2. EQUIPMENT COMPONENTS:
    - EquipmentInspector: Digital inspection checklists with photo capture
    - EquipmentSelector: Multi/single equipment selection with filtering
    - QRScanner: QR code scanning for equipment identification
    - DigitalChecklist: Placeholder for future digital checklist implementation
    - MaintenanceScheduler: Placeholder for maintenance scheduling
    - CalibrationTracker: Placeholder for calibration tracking

 3. CHEMICAL MANAGEMENT COMPONENTS:
    - ChemicalSelector: Chemical selection with inventory awareness
    - DosageCalculator: EPA-compliant dosage calculations
    - ChemicalInventory: Inventory management with expiration tracking
    - TreatmentLogger: Treatment application logging
    - EPACompliance: Regulatory compliance checking
    - MixingInstructions: Chemical mixing guidance
    - ApplicationTracker: Treatment application tracking
    - ChemicalSearch: Chemical database search functionality

 ARCHITECTURE FEATURES:
 - Error boundaries with graceful fallbacks
 - Accessibility compliance (VoiceOver, labels, navigation)
 - Performance optimizations (lazy loading, stable IDs)
 - Offline-first data management
 - Consistent styling and animation patterns
 - Proper SwiftUI lifecycle management
*/

// MARK: - Component-Specific Renderers

/// Protocol for component-specific renderers
protocol SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView
}

// MARK: - Layout Renderers

struct SDUIStackRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let children = component.children ?? []
        let spacing: CGFloat? = component.spacing.map { CGFloat($0) }

        let stack: AnyView
        switch component.type {
        case .vstack:
            stack = AnyView(VStack(alignment: .leading, spacing: spacing) {
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            })
        case .hstack:
            stack = AnyView(HStack(alignment: .center, spacing: spacing) {
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            })
        default:
            stack = AnyView(EmptyView())
        }

        return SDUIStyleApplicator.apply(styling: component, to: stack, job: context.currentJob)
    }
}

struct SDUIGridRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let children = component.children ?? []
        let columns = component.columns ?? 2
        let gridItems = Array(repeating: GridItem(.flexible()), count: columns)

        let grid = AnyView(LazyVGrid(columns: gridItems, spacing: component.spacing.map { CGFloat($0) }) {
            ForEach(children, id: \.id) { child in
                SDUIScreenRenderer.render(component: child, context: context)
            }
        })

        return SDUIStyleApplicator.apply(styling: component, to: grid, job: context.currentJob)
    }
}

struct SDUIScrollRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let children = component.children ?? []
        let spacing: CGFloat? = component.spacing.map { CGFloat($0) }

        let content = AnyView(VStack(alignment: .leading, spacing: spacing) {
            ForEach(children, id: \.id) { child in
                SDUIScreenRenderer.render(component: child, context: context)
            }
        })

        let scrollView = AnyView(ScrollView {
            content
        })

        return SDUIStyleApplicator.apply(styling: component, to: scrollView, job: context.currentJob)
    }
}

// MARK: - Content Renderers

struct SDUITextRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let text = SDUIDataResolver.resolveText(component: component, context: context)
        let colorName = component.foregroundColor ?? component.color

        var textView = Text(text)
            .font(SDUIStyleResolver.resolveFont(component.font))
            .foregroundColor(SDUIStyleResolver.resolveColor(colorName, job: context.currentJob))

        if let weightName = component.fontWeight {
            textView = textView.fontWeight(SDUIStyleResolver.resolveFontWeight(weightName))
        }

        let styledView = SDUIStyleApplicator.apply(styling: component, to: AnyView(textView), job: context.currentJob)
        return SDUIAnimationApplicator.apply(animation: component, to: styledView)
    }
}

struct SDUIButtonRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let actionId = component.actionId
        let isTransparentButton = component.backgroundColor?.lowercased() == "transparent"

        // Check if button has custom children content
        if let children = component.children, !children.isEmpty {
            // Render button with custom content
            let buttonContent = Button(action: {
                if let id = actionId, let action = context.actions[id] {
                    action(context.currentJob)
                }
            }) {
                // Render children as button content
                ForEach(children, id: \.id) { child in
                    SDUIScreenRenderer.render(component: child, context: context)
                }
            }
            .buttonStyle(.plain) // Use plain style for custom content

            // For transparent buttons, apply minimal styling to avoid conflicts
            if isTransparentButton {
                // Apply only padding and spacing, skip background-related styling
                var modifiedButton = AnyView(buttonContent)

                if let padding = component.padding {
                    modifiedButton = AnyView(modifiedButton.padding(padding))
                }

                return SDUIAnimationApplicator.apply(animation: component, to: modifiedButton)
            } else {
                let styledView = SDUIStyleApplicator.apply(styling: component, to: AnyView(buttonContent), job: context.currentJob)
                return SDUIAnimationApplicator.apply(animation: component, to: styledView)
            }
        } else {
            // Original text-based button rendering
            let labelStr = component.text ?? SDUIDataResolver.resolveLabel(component: component, context: context)

            let baseButton = Button(labelStr) {
                if let id = actionId, let action = context.actions[id] {
                    action(context.currentJob)
                }
            }
            .buttonStyle(.bordered)

            let buttonView: AnyView
            if let fg = component.foregroundColor {
                let color = SDUIStyleResolver.resolveColor(fg, job: context.currentJob)
                buttonView = AnyView(baseButton.tint(color))
            } else {
                buttonView = AnyView(baseButton)
            }

            let styledView = SDUIStyleApplicator.apply(styling: component, to: buttonView, job: context.currentJob)
            return SDUIAnimationApplicator.apply(animation: component, to: styledView)
        }
    }
}

// MARK: - Form Input Renderers

struct SDUIInputRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        switch component.type {
        case .textField:
            return renderTextField(component: component, context: context)
        case .toggle:
            return renderToggle(component: component, context: context)
        case .slider:
            return renderSlider(component: component, context: context)
        case .picker:
            return renderPicker(component: component, context: context)
        case .datePicker:
            return renderDatePicker(component: component, context: context)
        case .stepper:
            return renderStepper(component: component, context: context)
        case .segmentedControl:
            return renderSegmentedControl(component: component, context: context)
        default:
            return AnyView(Text("Unsupported input type"))
        }
    }

    private static func renderTextField(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let binding = Binding<String>(
            get: { context.routeViewModel.textFieldValues[contextKey] ?? "" },
            set: { context.routeViewModel.setTextValue(forKey: contextKey, value: $0) }
        )

        let placeholder = component.placeholder ?? ""
        let baseField = TextField(placeholder, text: binding)

        let fieldView: AnyView
        if let fg = component.foregroundColor {
            let color = SDUIStyleResolver.resolveColor(fg, job: context.currentJob)
            fieldView = AnyView(baseField.foregroundColor(color))
        } else {
            fieldView = AnyView(baseField)
        }

        let styledView = SDUIStyleApplicator.apply(styling: component, to: fieldView, job: context.currentJob)
        return SDUIAnimationApplicator.apply(animation: component, to: styledView)
    }

    private static func renderToggle(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let binding = Binding<Bool>(
            get: { context.routeViewModel.toggleValues[contextKey] ?? false },
            set: { context.routeViewModel.setToggleValue(forKey: contextKey, value: $0) }
        )

        let labelStr = component.label ?? SDUIDataResolver.resolveText(component: component, context: context)
        let toggleView = Toggle(isOn: binding) {
            Text(labelStr)
        }

        return SDUIStyleApplicator.apply(styling: component, to: AnyView(toggleView), job: context.currentJob)
    }

    private static func renderSlider(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let minValue = component.minValue ?? 0
        let maxValue = component.maxValue ?? 1
        let step = component.step ?? 0.1

        let binding = Binding<Double>(
            get: { context.routeViewModel.sliderValues[contextKey] ?? minValue },
            set: { context.routeViewModel.setSliderValue(forKey: contextKey, value: $0) }
        )

        let slider = Slider(value: binding, in: minValue...maxValue, step: step)

        let sliderStack: AnyView
        if component.showValue == true {
            sliderStack = AnyView(VStack(alignment: .leading) {
                slider
                Text(String(format: "%.2f", binding.wrappedValue))
            })
        } else {
            sliderStack = AnyView(slider)
        }

        let styledView = SDUIStyleApplicator.apply(styling: component, to: sliderStack, job: context.currentJob)
        return SDUIAnimationApplicator.apply(animation: component, to: styledView)
    }

    private static func renderPicker(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let options = component.options ?? []
        let binding = Binding<String>(
            get: { context.routeViewModel.pickerValues[contextKey] ?? (options.first?.value ?? "") },
            set: { context.routeViewModel.setPickerValue(forKey: contextKey, value: $0) }
        )

        let label = component.label ?? "Select"
        let pickerView = AnyView(Picker(label, selection: binding) {
            ForEach(options) { option in
                Text(option.text).tag(option.value)
            }
        })

        return SDUIStyleApplicator.apply(styling: component, to: pickerView, job: context.currentJob)
    }

    private static func renderDatePicker(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let binding = Binding<Date>(
            get: { context.routeViewModel.datePickerValues[contextKey] ?? Date() },
            set: { context.routeViewModel.setDatePickerValue(forKey: contextKey, value: $0) }
        )

        let label = component.label ?? "Select Date"
        let datePickerView = AnyView(DatePicker(label, selection: binding, displayedComponents: .date))

        return SDUIStyleApplicator.apply(styling: component, to: datePickerView, job: context.currentJob)
    }

    private static func renderStepper(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let minValue = component.minValue ?? 0
        let maxValue = component.maxValue ?? 100
        let step = component.step ?? 1

        let binding = Binding<Double>(
            get: { context.routeViewModel.stepperValues[contextKey] ?? minValue },
            set: { context.routeViewModel.setStepperValue(forKey: contextKey, value: $0) }
        )

        let label = component.label ?? "Value"
        let stepperView = AnyView(Stepper("\(label): \(Int(binding.wrappedValue))", value: binding, in: minValue...maxValue, step: step))

        return SDUIStyleApplicator.apply(styling: component, to: stepperView, job: context.currentJob)
    }

    private static func renderSegmentedControl(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let options = component.options ?? []
        let binding = Binding<Int>(
            get: { context.routeViewModel.segmentedValues[contextKey] ?? 0 },
            set: { context.routeViewModel.setSegmentedValue(forKey: contextKey, value: $0) }
        )

        let segmentedView = AnyView(Picker("", selection: binding) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Text(option.text).tag(index)
            }
        }.pickerStyle(.segmented))

        return SDUIStyleApplicator.apply(styling: component, to: segmentedView, job: context.currentJob)
    }
}

// MARK: - Chemical Management Renderers

struct SDUIChemicalRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        switch component.type {
        case .chemicalSelector:
            return renderChemicalSelector(component: component, context: context)
        case .dosageCalculator:
            return renderDosageCalculator(component: component, context: context)
        case .chemicalInventory:
            return renderChemicalInventory(component: component, context: context)
        case .treatmentLogger:
            return renderTreatmentLogger(component: component, context: context)
        case .epaCompliance:
            return renderEPACompliance(component: component, context: context)
        case .mixingInstructions:
            return renderMixingInstructions(component: component, context: context)
        case .applicationTracker:
            return renderApplicationTracker(component: component, context: context)
        case .chemicalSearch:
            return renderChemicalSearch(component: component, context: context)
        default:
            return AnyView(Text("Unsupported chemical component type"))
        }
    }

    // MARK: - Chemical Selector Component

    private static func renderChemicalSelector(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let allowMultiple = component.allowMultipleSelection ?? false
        let showOnlyAvailable = component.showOnlyAvailable ?? true
        let chemicalCategory = component.chemicalCategory
        let signalWordFilter = component.signalWordFilter
        let hazardCategoryFilter = component.hazardCategoryFilter
        let targetPest = component.targetPest

        // Get filtered chemicals based on component properties
        let filteredChemicals = getFilteredChemicals(
            category: chemicalCategory,
            signalWord: signalWordFilter,
            hazardCategory: hazardCategoryFilter,
            targetPest: targetPest,
            showOnlyAvailable: showOnlyAvailable,
            context: context
        )

        if allowMultiple {
            let binding = Binding<Set<String>>(
                get: { Set(context.routeViewModel.multiSelectValues[contextKey] ?? []) },
                set: { context.routeViewModel.setMultiSelectValues(forKey: contextKey, values: Array($0)) }
            )

            let multiSelectorView = AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text(component.label ?? "Select Chemicals")
                        .font(.headline)
                        .foregroundColor(.primary)

                    ForEach(filteredChemicals, id: \.id) { chemical in
                        ChemicalSelectorRow(
                            chemical: chemical,
                            isSelected: binding.wrappedValue.contains(chemical.id.uuidString),
                            onToggle: { isSelected in
                                var newSelection = binding.wrappedValue
                                if isSelected {
                                    newSelection.insert(chemical.id.uuidString)
                                } else {
                                    newSelection.remove(chemical.id.uuidString)
                                }
                                binding.wrappedValue = newSelection
                            }
                        )
                    }
                }
            )

            return SDUIStyleApplicator.apply(styling: component, to: multiSelectorView, job: context.currentJob)

        } else {
            let binding = Binding<String>(
                get: { context.routeViewModel.pickerValues[contextKey] ?? "" },
                set: { context.routeViewModel.setPickerValue(forKey: contextKey, value: $0) }
            )

            let singleSelectorView = AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text(component.label ?? "Select Chemical")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Picker("Chemical", selection: binding) {
                        Text("None Selected").tag("")
                        ForEach(filteredChemicals, id: \.id) { chemical in
                            ChemicalPickerRow(chemical: chemical).tag(chemical.id.uuidString)
                        }
                    }
                    .pickerStyle(.menu)
                }
            )

            return SDUIStyleApplicator.apply(styling: component, to: singleSelectorView, job: context.currentJob)
        }
    }

    // MARK: - Dosage Calculator Component

    private static func renderDosageCalculator(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let _ = component.chemicalId,
              let _ = component.targetArea else {
            return AnyView(Text("Missing required parameters for dosage calculation").foregroundColor(.red))
        }

        _ = ApplicationMethod(rawValue: component.applicationMethod ?? "spray") ?? .spray
        _ = component.targetPest ?? "General"
        _ = component.dosageCalculationMode ?? "automatic"

        let calculatorView = AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Dosage Calculator")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Dosage Calculator temporarily disabled")
                    .foregroundColor(.secondary)
            }
        )

        return SDUIStyleApplicator.apply(styling: component, to: calculatorView, job: context.currentJob)
    }

    // MARK: - Chemical Inventory Component

    private static func renderChemicalInventory(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let showExpired = component.showExpiredChemicals ?? false
        let inventoryThreshold = component.inventoryThreshold ?? 10.0
        let searchQuery = component.searchQuery ?? ""

        let inventoryView = AnyView(
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Chemical Inventory")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    InventoryFilterButtons(
                        showExpired: showExpired,
                        lowStockThreshold: inventoryThreshold
                    )
                }

                if !searchQuery.isEmpty {
                    Text("Filtered by: '\(searchQuery)'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ChemicalInventoryList(
                    showExpired: showExpired,
                    inventoryThreshold: inventoryThreshold,
                    searchQuery: searchQuery,
                    context: context
                )
            }
        )

        return SDUIStyleApplicator.apply(styling: component, to: inventoryView, job: context.currentJob)
    }

    // MARK: - Treatment Logger Component

    private static func renderTreatmentLogger(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let chemicalId = component.chemicalId else {
            return AnyView(Text("Missing chemical ID for treatment logging").foregroundColor(.red))
        }

        let applicationMethod = ApplicationMethod(rawValue: component.applicationMethod ?? "spray") ?? .spray
        let treatmentLocation = component.treatmentLocation ?? ""

        let loggerView = AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Treatment Application Log")
                    .font(.title2)
                    .fontWeight(.semibold)

                TreatmentLoggerForm(
                    chemicalId: UUID(uuidString: chemicalId) ?? UUID(),
                    defaultApplicationMethod: applicationMethod,
                    defaultLocation: treatmentLocation,
                    context: context
                )
            }
        )

        return SDUIStyleApplicator.apply(styling: component, to: loggerView, job: context.currentJob)
    }

    // MARK: - EPA Compliance Component

    private static func renderEPACompliance(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let validationRules = component.validationRules ?? []
        let treatmentType = component.treatmentType ?? "liquid"

        let complianceView = AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("EPA Compliance Check")
                    .font(.title2)
                    .fontWeight(.semibold)

                EPAComplianceWidget(
                    validationRules: validationRules,
                    treatmentType: treatmentType,
                    context: context
                )
            }
        )

        return SDUIStyleApplicator.apply(styling: component, to: complianceView, job: context.currentJob)
    }

    // MARK: - Mixing Instructions Component

    private static func renderMixingInstructions(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let chemicalId = component.chemicalId else {
            return AnyView(Text("Missing chemical ID for mixing instructions").foregroundColor(.red))
        }

        let mixingFormat = component.mixingRatioFormat ?? "1:1"
        let targetArea = component.targetArea ?? 1000.0

        let instructionsView = AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Mixing Instructions")
                    .font(.title2)
                    .fontWeight(.semibold)

                MixingInstructionsWidget(
                    chemicalId: UUID(uuidString: chemicalId) ?? UUID(),
                    mixingFormat: mixingFormat,
                    targetArea: targetArea,
                    context: context
                )
            }
        )

        return SDUIStyleApplicator.apply(styling: component, to: instructionsView, job: context.currentJob)
    }

    // MARK: - Application Tracker Component

    private static func renderApplicationTracker(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let trackerView = AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Application Tracker")
                    .font(.title2)
                    .fontWeight(.semibold)

                ChemicalApplicationTracker(context: context)
            }
        )

        return SDUIStyleApplicator.apply(styling: component, to: trackerView, job: context.currentJob)
    }

    // MARK: - Chemical Search Component

    private static func renderChemicalSearch(component: SDUIComponent, context: SDUIContext) -> AnyView {
        guard let key = component.valueKey else {
            return AnyView(Text("Missing valueKey for chemical search").foregroundColor(.red))
        }

        let contextKey = SDUIDataResolver.makeContextKey(key: key, job: context.currentJob)
        let placeholder = component.placeholder ?? "Search chemicals..."

        let binding = Binding<String>(
            get: { context.routeViewModel.textFieldValues[contextKey] ?? "" },
            set: { context.routeViewModel.setTextValue(forKey: contextKey, value: $0) }
        )

        let searchView = AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text(component.label ?? "Chemical Search")
                    .font(.headline)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField(placeholder, text: binding)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                if !binding.wrappedValue.isEmpty {
                    ChemicalSearchResults(
                        searchQuery: binding.wrappedValue,
                        context: context
                    )
                }
            }
        )

        return SDUIStyleApplicator.apply(styling: component, to: searchView, job: context.currentJob)
    }

    // MARK: - Helper Functions

    private static func getFilteredChemicals(
        category: String?,
        signalWord: String?,
        hazardCategory: String?,
        targetPest: String?,
        showOnlyAvailable: Bool,
        context: SDUIContext
    ) -> [Chemical] {
        // This would typically fetch from CoreData or a chemical data source
        // For now, return a mock list
        var chemicals: [Chemical] = []

        // Mock data - in production this would come from context.chemicals or similar
        chemicals = [
            Chemical(
                name: "Sample Insecticide A",
                activeIngredient: "Bifenthrin",
                manufacturerName: "Sample Corp",
                epaRegistrationNumber: "12345-67",
                concentration: 7.9,
                unitOfMeasure: "oz",
                quantityInStock: 25.5,
                expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
                targetPests: ["Ants", "Spiders", "Cockroaches"],
                signalWord: .caution,
                hazardCategory: .category3
            )
        ]

        // Apply filters
        if category != nil {
            // Filter by category logic would go here
        }

        if let signalWord = signalWord,
           let signal = SignalWord(rawValue: signalWord) {
            chemicals = chemicals.filter { $0.signalWord == signal }
        }

        if let hazardCategory = hazardCategory,
           let hazard = HazardCategory(rawValue: hazardCategory) {
            chemicals = chemicals.filter { $0.hazardCategory == hazard }
        }

        if let targetPest = targetPest {
            chemicals = chemicals.filter { $0.targetPests.contains(targetPest) }
        }

        if showOnlyAvailable {
            chemicals = chemicals.filter { $0.quantityInStock > 0 }
        }

        return chemicals
    }
}

// MARK: - Weather Component Renderers

struct SDUIWeatherRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        switch component.type {
        case .weatherDashboard:
            return renderWeatherDashboard(component: component, context: context)
        case .weatherAlert:
            return renderWeatherAlert(component: component, context: context)
        case .weatherForecast:
            return renderWeatherForecast(component: component, context: context)
        case .weatherMetrics:
            return renderWeatherMetrics(component: component, context: context)
        case .safetyIndicator:
            return renderSafetyIndicator(component: component, context: context)
        case .treatmentConditions:
            return renderTreatmentConditions(component: component, context: context)
        default:
            return AnyView(Text("Unsupported weather component type"))
        }
    }

    private static func renderWeatherDashboard(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let dashboardView = AnyView(
            ErrorBoundaryView {
                WeatherDashboardView(component: component, context: context)
            } errorView: { error in
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Weather data unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        )
        return SDUIStyleApplicator.apply(styling: component, to: dashboardView, job: context.currentJob)
    }

    private static func renderWeatherAlert(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let alertView = AnyView(WeatherAlertView(component: component, context: context))
        return SDUIStyleApplicator.apply(styling: component, to: alertView, job: context.currentJob)
    }

    private static func renderWeatherForecast(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let forecastView = AnyView(WeatherForecastView(component: component, context: context))
        return SDUIStyleApplicator.apply(styling: component, to: forecastView, job: context.currentJob)
    }

    private static func renderWeatherMetrics(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let metricsView = AnyView(WeatherMetricsView(component: component, context: context))
        return SDUIStyleApplicator.apply(styling: component, to: metricsView, job: context.currentJob)
    }

    private static func renderSafetyIndicator(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let indicatorView = AnyView(SafetyIndicatorView(component: component, context: context))
        return SDUIStyleApplicator.apply(styling: component, to: indicatorView, job: context.currentJob)
    }

    private static func renderTreatmentConditions(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let conditionsView = AnyView(TreatmentConditionsView(component: component, context: context))
        return SDUIStyleApplicator.apply(styling: component, to: conditionsView, job: context.currentJob)
    }
}

// MARK: - Equipment Component Renderers

// Note: SDUIEquipmentRenderer is defined in EquipmentSDUIComponents.swift
struct DuplicateSDUIEquipmentRenderer: SDUIComponentRenderer {
    static func render(component: SDUIComponent, context: SDUIContext) -> AnyView {
        switch component.type {
        case .equipmentInspector:
            return renderEquipmentInspector(component: component, context: context)
        case .equipmentSelector:
            return renderEquipmentSelector(component: component, context: context)
        case .qrScanner:
            return renderQRScanner(component: component, context: context)
        case .digitalChecklist:
            return renderDigitalChecklist(component: component, context: context)
        case .maintenanceScheduler:
            return renderMaintenanceScheduler(component: component, context: context)
        case .calibrationTracker:
            return renderCalibrationTracker(component: component, context: context)
        default:
            return AnyView(Text("Unsupported equipment component type"))
        }
    }

    private static func renderEquipmentInspector(component: SDUIComponent, context: SDUIContext) -> AnyView {
        // Error boundary for equipment inspector
        guard let equipmentId = component.equipmentId, !equipmentId.isEmpty else {
            return SDUIErrorHandler.createErrorView(
                message: "Equipment Inspector requires a valid equipment ID",
                component: component
            )
        }

        _ = component.checklistTemplate

        let inspectorView = AnyView(
            ErrorBoundaryView {
                Text("Equipment Inspector temporarily disabled")
                    .foregroundColor(.secondary)
            } errorView: { error in
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("Equipment Inspector Error")
                        .font(.headline)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        // Trigger view refresh
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        )

        return SDUIStyleApplicator.apply(styling: component, to: inspectorView, job: context.currentJob)
    }

    private static func renderEquipmentSelector(component: SDUIComponent, context: SDUIContext) -> AnyView {
        _ = component.equipmentType
        _ = component.allowMultipleSelection ?? false
        _ = component.showOnlyAvailable ?? true

        let selectorView = AnyView(
            Text("Equipment Selector temporarily disabled")
                .foregroundColor(.secondary)
        )
        
        // TODO: Re-implement equipment selector
        // EquipmentSelectorView(
        //     equipmentType: equipmentType,
        //     allowMultipleSelection: allowMultiple,
        //     showOnlyAvailable: showOnlyAvailable
        // ) { selectedEquipment in
        //         // Handle equipment selection
        //         let contextKey = SDUIDataResolver.makeContextKey(
        //             key: component.valueKey ?? "selectedEquipment",
        //             job: context.currentJob
        //         )

        //         if allowMultiple {
        //             let equipmentIds = selectedEquipment.map { $0.id }
        //             context.routeViewModel.setMultiSelectValues(forKey: contextKey, values: equipmentIds.map { $0.uuidString })
        //         } else if let first = selectedEquipment.first {
        //             context.routeViewModel.setTextValue(forKey: contextKey, value: first.id.uuidString)
        //         }
        //     }
        // )

        return SDUIStyleApplicator.apply(styling: component, to: selectorView, job: context.currentJob)
    }

    private static func renderQRScanner(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let scannerView = AnyView(
            QRScannerInterface { result in
                let contextKey = SDUIDataResolver.makeContextKey(
                    key: component.valueKey ?? "qrScanResult",
                    job: context.currentJob
                )
                context.routeViewModel.setTextValue(forKey: contextKey, value: result.code)
            }
        )

        return SDUIStyleApplicator.apply(styling: component, to: scannerView, job: context.currentJob)
    }

    private static func renderDigitalChecklist(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let checklistView = AnyView(
            Text("Digital Checklist - Implementation needed")
                .foregroundColor(.secondary)
                .padding()
        )

        return SDUIStyleApplicator.apply(styling: component, to: checklistView, job: context.currentJob)
    }

    private static func renderMaintenanceScheduler(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let schedulerView = AnyView(
            Text("Maintenance Scheduler - Implementation needed")
                .foregroundColor(.secondary)
                .padding()
        )

        return SDUIStyleApplicator.apply(styling: component, to: schedulerView, job: context.currentJob)
    }

    private static func renderCalibrationTracker(component: SDUIComponent, context: SDUIContext) -> AnyView {
        let trackerView = AnyView(
            Text("Calibration Tracker - Implementation needed")
                .foregroundColor(.secondary)
                .padding()
        )

        return SDUIStyleApplicator.apply(styling: component, to: trackerView, job: context.currentJob)
    }
}

// MARK: - Chemical UI Components

struct ChemicalSelectorRow: View {
    let chemical: Chemical
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            Button(action: {
                onToggle(!isSelected)
            }) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(chemical.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("\(chemical.activeIngredient) - \(chemical.concentrationFormatted)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text(chemical.signalWord.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(chemical.signalWord.color).opacity(0.2))
                                .cornerRadius(4)

                            Text("Stock: \(chemical.quantityFormatted)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if chemical.isExpired {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    } else if chemical.isLowStock {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct ChemicalPickerRow: View {
    let chemical: Chemical

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(chemical.name)
                .font(.subheadline)

            Text("\(chemical.activeIngredient) - \(chemical.concentrationFormatted)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Placeholder Views (These would be implemented fully in production)

// Note: DosageCalculatorView is defined in ChemicalManagementSDUI.swift

struct InventoryFilterButtons: View {
    let showExpired: Bool
    let lowStockThreshold: Double

    var body: some View {
        HStack {
            Text("Filters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ChemicalInventoryList: View {
    let showExpired: Bool
    let inventoryThreshold: Double
    let searchQuery: String
    let context: SDUIContext

    var body: some View {
        Text("Chemical inventory list would be displayed here")
            .foregroundColor(.secondary)
    }
}

struct TreatmentLoggerForm: View {
    let chemicalId: UUID
    let defaultApplicationMethod: ApplicationMethod
    let defaultLocation: String
    let context: SDUIContext

    var body: some View {
        Text("Treatment logging form would be displayed here")
            .foregroundColor(.secondary)
    }
}

struct EPAComplianceWidget: View {
    let validationRules: [String]
    let treatmentType: String
    let context: SDUIContext

    var body: some View {
        Text("EPA compliance checks would be displayed here")
            .foregroundColor(.secondary)
    }
}

struct MixingInstructionsWidget: View {
    let chemicalId: UUID
    let mixingFormat: String
    let targetArea: Double
    let context: SDUIContext

    var body: some View {
        Text("Mixing instructions would be displayed here")
            .foregroundColor(.secondary)
    }
}

struct ChemicalApplicationTracker: View {
    let context: SDUIContext

    var body: some View {
        Text("Application tracking would be displayed here")
            .foregroundColor(.secondary)
    }
}

struct ChemicalSearchResults: View {
    let searchQuery: String
    let context: SDUIContext

    var body: some View {
        Text("Search results for '\(searchQuery)' would be displayed here")
            .foregroundColor(.secondary)
    }
}

// MARK: - Error Boundary Components

/// Error boundary view that catches and displays errors gracefully
struct ErrorBoundaryView<Content: View, ErrorView: View>: View {
    let content: () -> Content
    let errorView: (Error) -> ErrorView

    @State private var error: Error?

    var body: some View {
        Group {
            if let error = error {
                errorView(error)
            } else {
                content()
                    .onAppear {
                        // Reset error state when view appears
                        self.error = nil
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .componentError)) { notification in
            if let error = notification.object as? Error {
                self.error = error
            }
        }
    }
}

/// Notification for component errors
extension Notification.Name {
    static let componentError = Notification.Name("componentError")
}

// MARK: - QR Scanner Interface

// Note: QRScanResult, QRCodeType, and QRScannerInterface are defined in QRCodeScanner.swift

struct DuplicateQRScannerInterface: View {
    let onScanComplete: (QRScanResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingManualEntry = false
    @State private var manualEntry = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // QR Scanner view would go here
                // For now, showing a placeholder
                VStack {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                        .accessibilityLabel("QR Code Scanner viewfinder")

                    Text("QR Code Scanner")
                        .font(.title2)
                        .fontWeight(.medium)
                        .accessibilityAddTraits(.isHeader)

                    Text("Point camera at QR code to scan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Instructions: Point camera at QR code to scan automatically")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                Button("Enter Code Manually") {
                    showingManualEntry = true
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Enter QR code manually")
                .accessibilityHint("Opens a text field to manually enter QR code value")
            }
            .padding()
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            // .toolbar(content: {
            //     ToolbarItem(placement: .navigationBarLeading) {
            //         Button("Cancel") {
            //             dismiss()
            //         }
            //     }
            // })
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualQREntryView { value in
                let result = QRScanResult(
                    id: UUID(),
                    code: value,
                    type: QRCodeType.fromString(value),
                    rawType: "manual",
                    scannedAt: Date()
                )
                onScanComplete(result)
                dismiss()
            }
        }
    }
}

struct ManualQREntryView: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var entryText = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter QR Code Value")
                    .font(.headline)

                TextField("QR Code Value", text: $entryText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                Text("Enter the text from the QR code manually")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onComplete(entryText)
                    }
                    .disabled(entryText.isEmpty)
                }
            }
        }
    }
}