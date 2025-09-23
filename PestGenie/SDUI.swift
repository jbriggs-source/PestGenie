import Foundation

/// Top level object describing a screen returned from the server. Contains a
/// version field for compatibility and a root component to render.
struct SDUIScreen: Codable {
    let version: Int
    let component: SDUIComponent
}

/// Enumerates the kinds of components supported by the SDUI engine. New types
/// can be added here to extend the renderer.
enum SDUIComponentType: String, Codable {
    // Layout containers
    case vstack
    case hstack
    case list
    case scroll
    case grid
    case tabView
    case section // grouped content with optional header/footer

    // Basic UI elements
    case text
    case button
    case spacer
    case image
    case divider
    case progressView

    // Form input components
    case textField
    case toggle
    case slider
    case picker
    case datePicker
    case stepper
    case segmentedControl

    // Navigation and presentation
    case navigationLink
    case actionSheet
    case alert

    // Logic and flow control
    case conditional
    case forEach

    // Advanced components
    case mapView
    case webView
    case chart
    case gauge

    // Equipment management components
    case equipmentInspector
    case equipmentSelector
    case qrScanner
    case digitalChecklist
    case maintenanceScheduler
    case calibrationTracker

    // Weather and environmental components
    case weatherDashboard
    case weatherAlert
    case weatherForecast
    case weatherMetrics
    case safetyIndicator
    case treatmentConditions

    // Chemical management components
    case chemicalSelector
    case dosageCalculator
    case chemicalInventory
    case treatmentLogger
    case epaCompliance
    case mixingInstructions
    case applicationTracker
    case chemicalSearch
}

/// Represents a component in the server‑driven UI. A component may have
/// children (for containers) or additional properties such as keys used to
/// resolve data from the job or static text/labels.
///
/// This is defined as a `class` rather than a `struct` to avoid the
/// “infinite size” compile error that arises when a value type recursively
/// references itself through optional and array properties. Classes are
/// reference types, so recursive references remain finite.
class SDUIComponent: Codable, Identifiable {
    /// Every component has a stable, non‑optional identifier. If the server
    /// does not provide one, a UUID is automatically generated. Having a
    /// non‑optional `id` avoids duplicate `nil` IDs when rendering with ForEach.
    var id: String
    let type: SDUIComponentType
    let key: String?
    let text: String?
    let label: String?
    let actionId: String?
    let font: String?
    let color: String?
    // Array of child components for container types (e.g. vstack, hstack, scroll).
    let children: [SDUIComponent]?
    // Template used for list rows. Only applicable when `type` is `.list`.
    let itemView: SDUIComponent?
    // Key used for conditional rendering. Children render only if the job's
    // property identified by this key has a non‑empty string value.
    let conditionKey: String?
    // MARK: - Styling tokens
    /// Optional padding to apply around the content. A single numeric value
    /// applies uniform padding. Defaults to nil, meaning no extra padding.
    let padding: Double?
    /// Spacing between children in stacks. Applies to VStack/HStack.
    let spacing: Double?
    /// Text or content colour. For buttons, images and text fields this
    /// overrides the default tint.
    let foregroundColor: String?
    /// Background colour. If specified with `cornerRadius` a rounded
    /// rectangle is drawn behind the component.
    let backgroundColor: String?
    /// Corner radius for the background shape. Used in conjunction with
    /// `backgroundColor`.
    let cornerRadius: Double?
    /// Font weight: e.g. "bold", "semibold". Only applicable to text.
    let fontWeight: String?
    // MARK: - Additional primitive properties
    /// Local asset name for image components.
    let imageName: String?
    /// Remote URL for image components. If both imageName and url are set,
    /// imageName takes precedence.
    let url: String?
    /// Key used to bind the value of inputs (text field, toggle, slider) into
    /// the view model's dictionaries. This should be unique within the scope
    /// of the screen.
    let valueKey: String?
    /// Placeholder text for inputs.
    let placeholder: String?
    /// Minimum value for sliders.
    let minValue: Double?
    /// Maximum value for sliders.
    let maxValue: Double?
    /// Step increment for sliders.
    let step: Double?
    /// Whether to display the numeric value of the slider alongside the control.
    let showValue: Bool?

    // MARK: - Grid layout properties
    /// Number of columns for grid layouts.
    let columns: Int?
    /// Grid item size mode: "fixed", "flexible", "adaptive".
    let gridItemSize: String?
    /// Minimum size for adaptive grid items.
    let gridItemMinSize: Double?

    // MARK: - Picker properties
    /// Array of picker options for picker components.
    let options: [SDUIPickerOption]?
    /// Selection mode: "single", "multiple".
    let selectionMode: String?

    // MARK: - Navigation properties
    /// Destination screen identifier for navigation links.
    let destination: String?
    /// Alert/sheet presentation properties.
    let isPresented: String? // key to bind presentation state
    var title: String?
    var message: String?

    // MARK: - Progress and gauge properties
    /// Current progress value (0.0 to 1.0).
    let progress: Double?
    /// Gauge range minimum value.
    let gaugeMin: Double?
    /// Gauge range maximum value.
    let gaugeMax: Double?

    // MARK: - Map properties
    /// Initial map region center latitude.
    let centerLatitude: Double?
    /// Initial map region center longitude.
    let centerLongitude: Double?
    /// Map zoom level/span.
    let span: Double?

    // MARK: - Web view properties
    /// URL to load in web view.
    let webURL: String?

    // MARK: - Chart properties
    /// Chart type: "line", "bar", "pie".
    let chartType: String?
    /// Data source key for chart data.
    let dataKey: String?

    // MARK: - Advanced styling
    /// Border width in points.
    let borderWidth: Double?
    /// Border color.
    let borderColor: String?
    /// Shadow properties.
    let shadowRadius: Double?
    let shadowColor: String?
    let shadowOffset: SDUIShadowOffset?
    /// Opacity (0.0 to 1.0).
    let opacity: Double?
    /// Rotation angle in degrees.
    let rotation: Double?
    /// Scale factor.
    let scale: Double?

    // MARK: - Equipment management properties
    /// Equipment type filter for selector: "sprayer", "backpack", "probe", etc.
    let equipmentType: String?
    /// Equipment category for grouping: "spray_equipment", "detection", "calibration".
    let equipmentCategory: String?
    /// QR code value for equipment identification.
    let qrCodeValue: String?
    /// Inspection checklist template identifier.
    let checklistTemplate: String?
    /// Equipment ID for specific equipment operations.
    let equipmentId: String?
    /// Maintenance type: "routine", "repair", "calibration".
    let maintenanceType: String?
    /// Allow multiple equipment selection in selector.
    let allowMultipleSelection: Bool?
    /// Show only available/active equipment.
    let showOnlyAvailable: Bool?
    /// Equipment status filter: "active", "maintenance", "calibration".
    let statusFilter: String?

    // MARK: - Weather component properties
    /// Weather data source: "current", "forecast", "historical".
    let weatherDataSource: String?
    /// Weather location mode: "current", "job_location", "manual".
    let weatherLocationMode: String?
    /// Manual weather coordinates when using manual location mode.
    let weatherLatitude: Double?
    let weatherLongitude: Double?
    /// Weather display mode: "compact", "detailed", "minimal".
    let weatherDisplayMode: String?
    /// Weather metrics to show: array of "temperature", "humidity", "wind", etc.
    let weatherMetrics: [String]?
    /// Show weather alerts in dashboard.
    let showWeatherAlerts: Bool?
    /// Weather safety threshold configuration.
    let safetyThresholds: SDUIWeatherThresholds?
    /// Auto-refresh interval for weather data in seconds.
    let weatherRefreshInterval: Double?
    /// Weather alert priority filter: "low", "normal", "high", "critical".
    let alertPriorityFilter: String?
    /// Treatment type for safety validation: "liquid", "granular", "spray".
    let treatmentType: String?

    // MARK: - Chemical management properties
    /// Chemical ID for specific chemical operations.
    let chemicalId: String?
    /// Chemical category filter: "insecticide", "herbicide", "fungicide", "rodenticide".
    let chemicalCategory: String?
    /// Signal word filter: "DANGER", "WARNING", "CAUTION".
    let signalWordFilter: String?
    /// Hazard category filter: "Category I", "Category II", "Category III", "Category IV".
    let hazardCategoryFilter: String?
    /// Target area for dosage calculation in square feet.
    let targetArea: Double?
    /// Application method: "spray", "bait", "dust", "granular", etc.
    let applicationMethod: String?
    /// Target pest for chemical selection and dosage calculation.
    let targetPest: String?
    /// Chemical search query for filtering.
    let searchQuery: String?
    /// EPA registration number for specific chemical lookup.
    let epaRegistrationNumber: String?
    /// Inventory threshold for low stock warnings.
    let inventoryThreshold: Double?
    /// Show expired chemicals in inventory.
    let showExpiredChemicals: Bool?
    /// Treatment location for application tracking.
    let treatmentLocation: String?
    /// Dosage calculation mode: "automatic", "manual", "custom".
    let dosageCalculationMode: String?
    /// Chemical mixing ratio format: "1:1", "percentage", "parts_per_million".
    let mixingRatioFormat: String?
    /// Treatment validation rules for EPA compliance.
    let validationRules: [String]?

    // MARK: - Animation and transitions
    /// Optional animation definition to apply to the component's appearance.
    let animation: SDUIAnimation?
    /// Optional transition definition to apply when the component appears/disappears.
    let transition: SDUITransition?

    enum CodingKeys: String, CodingKey {
        case id, type, key, text, label, actionId, font, color, children, itemView, conditionKey,
             padding, spacing, foregroundColor, backgroundColor, cornerRadius, fontWeight,
             imageName, url, valueKey, placeholder, minValue, maxValue, step, showValue,
             columns, gridItemSize, gridItemMinSize, options, selectionMode,
             destination, isPresented, title, message, progress, gaugeMin, gaugeMax,
             centerLatitude, centerLongitude, span, webURL, chartType, dataKey,
             borderWidth, borderColor, shadowRadius, shadowColor, shadowOffset,
             opacity, rotation, scale, equipmentType, equipmentCategory, qrCodeValue,
             checklistTemplate, equipmentId, maintenanceType, allowMultipleSelection,
             showOnlyAvailable, statusFilter, weatherDataSource, weatherLocationMode,
             weatherLatitude, weatherLongitude, weatherDisplayMode, weatherMetrics,
             showWeatherAlerts, safetyThresholds, weatherRefreshInterval,
             alertPriorityFilter, treatmentType, chemicalId, chemicalCategory,
             signalWordFilter, hazardCategoryFilter, targetArea, applicationMethod,
             targetPest, searchQuery, epaRegistrationNumber, inventoryThreshold,
             showExpiredChemicals, treatmentLocation, dosageCalculationMode,
             mixingRatioFormat, validationRules, animation, transition
    }

    /// Memberwise initializer. If `id` is nil, a UUID will be generated.
    init(id: String? = nil,
         type: SDUIComponentType,
         key: String? = nil,
         text: String? = nil,
         label: String? = nil,
         actionId: String? = nil,
         font: String? = nil,
         color: String? = nil,
         children: [SDUIComponent]? = nil,
         itemView: SDUIComponent? = nil,
         conditionKey: String? = nil,
         // Styling tokens
         padding: Double? = nil,
         spacing: Double? = nil,
         foregroundColor: String? = nil,
         backgroundColor: String? = nil,
         cornerRadius: Double? = nil,
         fontWeight: String? = nil,
         // Additional primitive properties
         imageName: String? = nil,
         url: String? = nil,
         valueKey: String? = nil,
         placeholder: String? = nil,
         minValue: Double? = nil,
         maxValue: Double? = nil,
         step: Double? = nil,
         showValue: Bool? = nil,
         // Grid properties
         columns: Int? = nil,
         gridItemSize: String? = nil,
         gridItemMinSize: Double? = nil,
         // Picker properties
         options: [SDUIPickerOption]? = nil,
         selectionMode: String? = nil,
         // Navigation properties
         destination: String? = nil,
         isPresented: String? = nil,
         title: String? = nil,
         message: String? = nil,
         // Progress/gauge properties
         progress: Double? = nil,
         gaugeMin: Double? = nil,
         gaugeMax: Double? = nil,
         // Map properties
         centerLatitude: Double? = nil,
         centerLongitude: Double? = nil,
         span: Double? = nil,
         // Web view properties
         webURL: String? = nil,
         // Chart properties
         chartType: String? = nil,
         dataKey: String? = nil,
         // Advanced styling
         borderWidth: Double? = nil,
         borderColor: String? = nil,
         shadowRadius: Double? = nil,
         shadowColor: String? = nil,
         shadowOffset: SDUIShadowOffset? = nil,
         opacity: Double? = nil,
         rotation: Double? = nil,
         scale: Double? = nil,
         // Equipment properties
         equipmentType: String? = nil,
         equipmentCategory: String? = nil,
         qrCodeValue: String? = nil,
         checklistTemplate: String? = nil,
         equipmentId: String? = nil,
         maintenanceType: String? = nil,
         allowMultipleSelection: Bool? = nil,
         showOnlyAvailable: Bool? = nil,
         statusFilter: String? = nil,
         // Weather properties
         weatherDataSource: String? = nil,
         weatherLocationMode: String? = nil,
         weatherLatitude: Double? = nil,
         weatherLongitude: Double? = nil,
         weatherDisplayMode: String? = nil,
         weatherMetrics: [String]? = nil,
         showWeatherAlerts: Bool? = nil,
         safetyThresholds: SDUIWeatherThresholds? = nil,
         weatherRefreshInterval: Double? = nil,
         alertPriorityFilter: String? = nil,
         treatmentType: String? = nil,
         // Chemical properties
         chemicalId: String? = nil,
         chemicalCategory: String? = nil,
         signalWordFilter: String? = nil,
         hazardCategoryFilter: String? = nil,
         targetArea: Double? = nil,
         applicationMethod: String? = nil,
         targetPest: String? = nil,
         searchQuery: String? = nil,
         epaRegistrationNumber: String? = nil,
         inventoryThreshold: Double? = nil,
         showExpiredChemicals: Bool? = nil,
         treatmentLocation: String? = nil,
         dosageCalculationMode: String? = nil,
         mixingRatioFormat: String? = nil,
         validationRules: [String]? = nil,
         animation: SDUIAnimation? = nil,
         transition: SDUITransition? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.type = type
        self.key = key
        self.text = text
        self.label = label
        self.actionId = actionId
        self.font = font
        self.color = color
        self.children = children
        self.itemView = itemView
        self.conditionKey = conditionKey
        self.padding = padding
        self.spacing = spacing
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.fontWeight = fontWeight
        self.imageName = imageName
        self.url = url
        self.valueKey = valueKey
        self.placeholder = placeholder
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.showValue = showValue
        self.columns = columns
        self.gridItemSize = gridItemSize
        self.gridItemMinSize = gridItemMinSize
        self.options = options
        self.selectionMode = selectionMode
        self.destination = destination
        self.isPresented = isPresented
        self.title = title
        self.message = message
        self.progress = progress
        self.gaugeMin = gaugeMin
        self.gaugeMax = gaugeMax
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.span = span
        self.webURL = webURL
        self.chartType = chartType
        self.dataKey = dataKey
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.shadowRadius = shadowRadius
        self.shadowColor = shadowColor
        self.shadowOffset = shadowOffset
        self.opacity = opacity
        self.rotation = rotation
        self.scale = scale
        self.equipmentType = equipmentType
        self.equipmentCategory = equipmentCategory
        self.qrCodeValue = qrCodeValue
        self.checklistTemplate = checklistTemplate
        self.equipmentId = equipmentId
        self.maintenanceType = maintenanceType
        self.allowMultipleSelection = allowMultipleSelection
        self.showOnlyAvailable = showOnlyAvailable
        self.statusFilter = statusFilter
        self.weatherDataSource = weatherDataSource
        self.weatherLocationMode = weatherLocationMode
        self.weatherLatitude = weatherLatitude
        self.weatherLongitude = weatherLongitude
        self.weatherDisplayMode = weatherDisplayMode
        self.weatherMetrics = weatherMetrics
        self.showWeatherAlerts = showWeatherAlerts
        self.safetyThresholds = safetyThresholds
        self.weatherRefreshInterval = weatherRefreshInterval
        self.alertPriorityFilter = alertPriorityFilter
        self.treatmentType = treatmentType
        self.chemicalId = chemicalId
        self.chemicalCategory = chemicalCategory
        self.signalWordFilter = signalWordFilter
        self.hazardCategoryFilter = hazardCategoryFilter
        self.targetArea = targetArea
        self.applicationMethod = applicationMethod
        self.targetPest = targetPest
        self.searchQuery = searchQuery
        self.epaRegistrationNumber = epaRegistrationNumber
        self.inventoryThreshold = inventoryThreshold
        self.showExpiredChemicals = showExpiredChemicals
        self.treatmentLocation = treatmentLocation
        self.dosageCalculationMode = dosageCalculationMode
        self.mixingRatioFormat = mixingRatioFormat
        self.validationRules = validationRules
        self.animation = animation
        self.transition = transition
    }

    /// Custom decoding to assign a UUID if the id is missing in the payload.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Attempt to decode an ID from the payload; generate one if absent.
        let decodedId = try container.decodeIfPresent(String.self, forKey: .id)
        self.id = decodedId ?? UUID().uuidString
        self.type = try container.decode(SDUIComponentType.self, forKey: .type)
        self.key = try container.decodeIfPresent(String.self, forKey: .key)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
        self.actionId = try container.decodeIfPresent(String.self, forKey: .actionId)
        self.font = try container.decodeIfPresent(String.self, forKey: .font)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.children = try container.decodeIfPresent([SDUIComponent].self, forKey: .children)
        self.itemView = try container.decodeIfPresent(SDUIComponent.self, forKey: .itemView)
        self.conditionKey = try container.decodeIfPresent(String.self, forKey: .conditionKey)
        self.padding = try container.decodeIfPresent(Double.self, forKey: .padding)
        self.spacing = try container.decodeIfPresent(Double.self, forKey: .spacing)
        self.foregroundColor = try container.decodeIfPresent(String.self, forKey: .foregroundColor)
        self.backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        self.cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius)
        self.fontWeight = try container.decodeIfPresent(String.self, forKey: .fontWeight)
        self.imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.valueKey = try container.decodeIfPresent(String.self, forKey: .valueKey)
        self.placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        self.minValue = try container.decodeIfPresent(Double.self, forKey: .minValue)
        self.maxValue = try container.decodeIfPresent(Double.self, forKey: .maxValue)
        self.step = try container.decodeIfPresent(Double.self, forKey: .step)
        self.showValue = try container.decodeIfPresent(Bool.self, forKey: .showValue)
        self.columns = try container.decodeIfPresent(Int.self, forKey: .columns)
        self.gridItemSize = try container.decodeIfPresent(String.self, forKey: .gridItemSize)
        self.gridItemMinSize = try container.decodeIfPresent(Double.self, forKey: .gridItemMinSize)
        self.options = try container.decodeIfPresent([SDUIPickerOption].self, forKey: .options)
        self.selectionMode = try container.decodeIfPresent(String.self, forKey: .selectionMode)
        self.destination = try container.decodeIfPresent(String.self, forKey: .destination)
        self.isPresented = try container.decodeIfPresent(String.self, forKey: .isPresented)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.progress = try container.decodeIfPresent(Double.self, forKey: .progress)
        self.gaugeMin = try container.decodeIfPresent(Double.self, forKey: .gaugeMin)
        self.gaugeMax = try container.decodeIfPresent(Double.self, forKey: .gaugeMax)
        self.centerLatitude = try container.decodeIfPresent(Double.self, forKey: .centerLatitude)
        self.centerLongitude = try container.decodeIfPresent(Double.self, forKey: .centerLongitude)
        self.span = try container.decodeIfPresent(Double.self, forKey: .span)
        self.webURL = try container.decodeIfPresent(String.self, forKey: .webURL)
        self.chartType = try container.decodeIfPresent(String.self, forKey: .chartType)
        self.dataKey = try container.decodeIfPresent(String.self, forKey: .dataKey)
        self.borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth)
        self.borderColor = try container.decodeIfPresent(String.self, forKey: .borderColor)
        self.shadowRadius = try container.decodeIfPresent(Double.self, forKey: .shadowRadius)
        self.shadowColor = try container.decodeIfPresent(String.self, forKey: .shadowColor)
        self.shadowOffset = try container.decodeIfPresent(SDUIShadowOffset.self, forKey: .shadowOffset)
        self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity)
        self.rotation = try container.decodeIfPresent(Double.self, forKey: .rotation)
        self.scale = try container.decodeIfPresent(Double.self, forKey: .scale)
        self.animation = try container.decodeIfPresent(SDUIAnimation.self, forKey: .animation)
        self.transition = try container.decodeIfPresent(SDUITransition.self, forKey: .transition)
        // Equipment properties
        self.equipmentType = try container.decodeIfPresent(String.self, forKey: .equipmentType)
        self.equipmentCategory = try container.decodeIfPresent(String.self, forKey: .equipmentCategory)
        self.qrCodeValue = try container.decodeIfPresent(String.self, forKey: .qrCodeValue)
        self.checklistTemplate = try container.decodeIfPresent(String.self, forKey: .checklistTemplate)
        self.equipmentId = try container.decodeIfPresent(String.self, forKey: .equipmentId)
        self.maintenanceType = try container.decodeIfPresent(String.self, forKey: .maintenanceType)
        self.allowMultipleSelection = try container.decodeIfPresent(Bool.self, forKey: .allowMultipleSelection)
        self.showOnlyAvailable = try container.decodeIfPresent(Bool.self, forKey: .showOnlyAvailable)
        self.statusFilter = try container.decodeIfPresent(String.self, forKey: .statusFilter)
        // Weather properties
        self.weatherDataSource = try container.decodeIfPresent(String.self, forKey: .weatherDataSource)
        self.weatherLocationMode = try container.decodeIfPresent(String.self, forKey: .weatherLocationMode)
        self.weatherLatitude = try container.decodeIfPresent(Double.self, forKey: .weatherLatitude)
        self.weatherLongitude = try container.decodeIfPresent(Double.self, forKey: .weatherLongitude)
        self.weatherDisplayMode = try container.decodeIfPresent(String.self, forKey: .weatherDisplayMode)
        self.weatherMetrics = try container.decodeIfPresent([String].self, forKey: .weatherMetrics)
        self.showWeatherAlerts = try container.decodeIfPresent(Bool.self, forKey: .showWeatherAlerts)
        self.safetyThresholds = try container.decodeIfPresent(SDUIWeatherThresholds.self, forKey: .safetyThresholds)
        self.weatherRefreshInterval = try container.decodeIfPresent(Double.self, forKey: .weatherRefreshInterval)
        self.alertPriorityFilter = try container.decodeIfPresent(String.self, forKey: .alertPriorityFilter)
        self.treatmentType = try container.decodeIfPresent(String.self, forKey: .treatmentType)
        // Chemical properties
        self.chemicalId = try container.decodeIfPresent(String.self, forKey: .chemicalId)
        self.chemicalCategory = try container.decodeIfPresent(String.self, forKey: .chemicalCategory)
        self.signalWordFilter = try container.decodeIfPresent(String.self, forKey: .signalWordFilter)
        self.hazardCategoryFilter = try container.decodeIfPresent(String.self, forKey: .hazardCategoryFilter)
        self.targetArea = try container.decodeIfPresent(Double.self, forKey: .targetArea)
        self.applicationMethod = try container.decodeIfPresent(String.self, forKey: .applicationMethod)
        self.targetPest = try container.decodeIfPresent(String.self, forKey: .targetPest)
        self.searchQuery = try container.decodeIfPresent(String.self, forKey: .searchQuery)
        self.epaRegistrationNumber = try container.decodeIfPresent(String.self, forKey: .epaRegistrationNumber)
        self.inventoryThreshold = try container.decodeIfPresent(Double.self, forKey: .inventoryThreshold)
        self.showExpiredChemicals = try container.decodeIfPresent(Bool.self, forKey: .showExpiredChemicals)
        self.treatmentLocation = try container.decodeIfPresent(String.self, forKey: .treatmentLocation)
        self.dosageCalculationMode = try container.decodeIfPresent(String.self, forKey: .dosageCalculationMode)
        self.mixingRatioFormat = try container.decodeIfPresent(String.self, forKey: .mixingRatioFormat)
        self.validationRules = try container.decodeIfPresent([String].self, forKey: .validationRules)
    }

    /// Custom encoding to ensure all properties, including the generated id,
    /// are persisted. With automatic synthesis, the missing id would be
    /// encoded as nil if it came from a generated UUID, which could lead to
    /// inconsistent IDs when re‑encoding.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(key, forKey: .key)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(actionId, forKey: .actionId)
        try container.encodeIfPresent(font, forKey: .font)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(children, forKey: .children)
        try container.encodeIfPresent(itemView, forKey: .itemView)
        try container.encodeIfPresent(conditionKey, forKey: .conditionKey)
        try container.encodeIfPresent(padding, forKey: .padding)
        try container.encodeIfPresent(spacing, forKey: .spacing)
        try container.encodeIfPresent(foregroundColor, forKey: .foregroundColor)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(cornerRadius, forKey: .cornerRadius)
        try container.encodeIfPresent(fontWeight, forKey: .fontWeight)
        try container.encodeIfPresent(imageName, forKey: .imageName)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(valueKey, forKey: .valueKey)
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
        try container.encodeIfPresent(minValue, forKey: .minValue)
        try container.encodeIfPresent(maxValue, forKey: .maxValue)
        try container.encodeIfPresent(step, forKey: .step)
        try container.encodeIfPresent(showValue, forKey: .showValue)
        try container.encodeIfPresent(columns, forKey: .columns)
        try container.encodeIfPresent(gridItemSize, forKey: .gridItemSize)
        try container.encodeIfPresent(gridItemMinSize, forKey: .gridItemMinSize)
        try container.encodeIfPresent(options, forKey: .options)
        try container.encodeIfPresent(selectionMode, forKey: .selectionMode)
        try container.encodeIfPresent(destination, forKey: .destination)
        try container.encodeIfPresent(isPresented, forKey: .isPresented)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(progress, forKey: .progress)
        try container.encodeIfPresent(gaugeMin, forKey: .gaugeMin)
        try container.encodeIfPresent(gaugeMax, forKey: .gaugeMax)
        try container.encodeIfPresent(centerLatitude, forKey: .centerLatitude)
        try container.encodeIfPresent(centerLongitude, forKey: .centerLongitude)
        try container.encodeIfPresent(span, forKey: .span)
        try container.encodeIfPresent(webURL, forKey: .webURL)
        try container.encodeIfPresent(chartType, forKey: .chartType)
        try container.encodeIfPresent(dataKey, forKey: .dataKey)
        try container.encodeIfPresent(borderWidth, forKey: .borderWidth)
        try container.encodeIfPresent(borderColor, forKey: .borderColor)
        try container.encodeIfPresent(shadowRadius, forKey: .shadowRadius)
        try container.encodeIfPresent(shadowColor, forKey: .shadowColor)
        try container.encodeIfPresent(shadowOffset, forKey: .shadowOffset)
        try container.encodeIfPresent(opacity, forKey: .opacity)
        try container.encodeIfPresent(rotation, forKey: .rotation)
        try container.encodeIfPresent(scale, forKey: .scale)
        try container.encodeIfPresent(animation, forKey: .animation)
        try container.encodeIfPresent(transition, forKey: .transition)
        // Equipment properties
        try container.encodeIfPresent(equipmentType, forKey: .equipmentType)
        try container.encodeIfPresent(equipmentCategory, forKey: .equipmentCategory)
        try container.encodeIfPresent(qrCodeValue, forKey: .qrCodeValue)
        try container.encodeIfPresent(checklistTemplate, forKey: .checklistTemplate)
        try container.encodeIfPresent(equipmentId, forKey: .equipmentId)
        try container.encodeIfPresent(maintenanceType, forKey: .maintenanceType)
        try container.encodeIfPresent(allowMultipleSelection, forKey: .allowMultipleSelection)
        try container.encodeIfPresent(showOnlyAvailable, forKey: .showOnlyAvailable)
        try container.encodeIfPresent(statusFilter, forKey: .statusFilter)
        // Weather properties
        try container.encodeIfPresent(weatherDataSource, forKey: .weatherDataSource)
        try container.encodeIfPresent(weatherLocationMode, forKey: .weatherLocationMode)
        try container.encodeIfPresent(weatherLatitude, forKey: .weatherLatitude)
        try container.encodeIfPresent(weatherLongitude, forKey: .weatherLongitude)
        try container.encodeIfPresent(weatherDisplayMode, forKey: .weatherDisplayMode)
        try container.encodeIfPresent(weatherMetrics, forKey: .weatherMetrics)
        try container.encodeIfPresent(showWeatherAlerts, forKey: .showWeatherAlerts)
        try container.encodeIfPresent(safetyThresholds, forKey: .safetyThresholds)
        try container.encodeIfPresent(weatherRefreshInterval, forKey: .weatherRefreshInterval)
        try container.encodeIfPresent(alertPriorityFilter, forKey: .alertPriorityFilter)
        try container.encodeIfPresent(treatmentType, forKey: .treatmentType)
        // Chemical properties
        try container.encodeIfPresent(chemicalId, forKey: .chemicalId)
        try container.encodeIfPresent(chemicalCategory, forKey: .chemicalCategory)
        try container.encodeIfPresent(signalWordFilter, forKey: .signalWordFilter)
        try container.encodeIfPresent(hazardCategoryFilter, forKey: .hazardCategoryFilter)
        try container.encodeIfPresent(targetArea, forKey: .targetArea)
        try container.encodeIfPresent(applicationMethod, forKey: .applicationMethod)
        try container.encodeIfPresent(targetPest, forKey: .targetPest)
        try container.encodeIfPresent(searchQuery, forKey: .searchQuery)
        try container.encodeIfPresent(epaRegistrationNumber, forKey: .epaRegistrationNumber)
        try container.encodeIfPresent(inventoryThreshold, forKey: .inventoryThreshold)
        try container.encodeIfPresent(showExpiredChemicals, forKey: .showExpiredChemicals)
        try container.encodeIfPresent(treatmentLocation, forKey: .treatmentLocation)
        try container.encodeIfPresent(dosageCalculationMode, forKey: .dosageCalculationMode)
        try container.encodeIfPresent(mixingRatioFormat, forKey: .mixingRatioFormat)
        try container.encodeIfPresent(validationRules, forKey: .validationRules)
    }
}

/// Represents an animation configuration for a component. Each animation may
/// specify a type (e.g. "easeInOut", "linear", "spring") and a duration in
/// seconds. Additional parameters could be added in future versions.
struct SDUIAnimation: Codable {
    let type: String?
    let duration: Double?
}

/// Represents a transition configuration. The `type` can be any of SwiftUI's
/// built‑in transition identifiers ("slide", "opacity", "scale", etc.).
struct SDUITransition: Codable {
    let type: String?
}

/// Represents a picker option with display text and value.
struct SDUIPickerOption: Codable, Identifiable {
    let id: String
    let text: String
    let value: String

    init(id: String? = nil, text: String, value: String) {
        self.id = id ?? UUID().uuidString
        self.text = text
        self.value = value
    }
}

/// Represents shadow offset for advanced styling.
struct SDUIShadowOffset: Codable {
    let x: Double
    let y: Double

    init(x: Double = 0, y: Double = 2) {
        self.x = x
        self.y = y
    }
}

/// Represents chart data point for chart components.
struct SDUIChartData: Codable {
    let label: String
    let value: Double
    let color: String?

    init(label: String, value: Double, color: String? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }
}

// Note: SDUIWeatherThresholds is defined in WeatherSDUIComponents.swift