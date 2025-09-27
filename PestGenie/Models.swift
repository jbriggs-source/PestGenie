import Foundation
import CoreLocation
import CoreData
import SwiftUI


// MARK: - Weather Data Models

/// Lightweight weather snapshot for job logging
struct WeatherSnapshot: Codable, Equatable {
    let temperature: Double
    let humidity: Int
    let windSpeed: Double
    let windDirection: Double
    let condition: String
    let timestamp: Date
    let isSafeForTreatment: Bool
}

/// Comprehensive weather data with treatment safety analysis
struct WeatherConditions: Identifiable, Codable {
    let id: UUID
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let pressure: Double
    let windSpeed: Double
    let windDirection: Double
    let uvIndex: Double
    let precipitationProbability: Int
    let visibility: Double
    let cloudCover: Int
    let condition: String
    let description: String
    let timestamp: Date
    let location: CLLocationCoordinate2D
    let safetyAnalysis: TreatmentSafetyAnalysis

    init(from weatherData: WeatherData) {
        self.id = weatherData.id
        self.temperature = weatherData.temperature
        self.feelsLike = weatherData.feelsLike
        self.humidity = weatherData.humidity
        self.pressure = weatherData.pressure
        self.windSpeed = weatherData.windSpeed
        self.windDirection = weatherData.windDirection
        self.uvIndex = weatherData.uvIndex
        self.precipitationProbability = weatherData.precipitationProbability
        self.visibility = weatherData.visibility
        self.cloudCover = weatherData.cloudCover
        self.condition = weatherData.condition
        self.description = weatherData.description
        self.timestamp = weatherData.timestamp
        self.location = weatherData.location
        self.safetyAnalysis = TreatmentSafetyAnalysis(from: weatherData)
    }
}

/// Treatment safety analysis based on weather conditions
struct TreatmentSafetyAnalysis: Codable {
    let overallSafety: SafetyLevel
    let canApplyLiquidTreatments: Bool
    let canApplyGranularTreatments: Bool
    let canUseSprayEquipment: Bool
    let recommendedTimeWindow: TimeWindow?
    let warnings: [WeatherWarning]
    let recommendations: [String]

    init(from weatherData: WeatherData) {
        // Wind speed analysis
        let windSafe = weatherData.windSpeed <= 10
        let moderateWind = weatherData.windSpeed <= 15

        // Temperature analysis
        let tempOptimal = weatherData.temperature >= 55 && weatherData.temperature <= 80
        let tempAcceptable = weatherData.temperature >= 45 && weatherData.temperature <= 90

        // Precipitation analysis
        let precipitationSafe = weatherData.precipitationProbability < 30

        // Calculate overall safety
        if windSafe && tempOptimal && precipitationSafe {
            self.overallSafety = .optimal
        } else if moderateWind && tempAcceptable && weatherData.precipitationProbability < 50 {
            self.overallSafety = .acceptable
        } else if weatherData.windSpeed > 20 || weatherData.precipitationProbability > 70 {
            self.overallSafety = .unsafe
        } else {
            self.overallSafety = .caution
        }

        // Treatment type recommendations
        self.canApplyLiquidTreatments = weatherData.windSpeed <= 15 && weatherData.precipitationProbability < 50
        self.canApplyGranularTreatments = weatherData.windSpeed <= 20 && weatherData.precipitationProbability < 30
        self.canUseSprayEquipment = weatherData.windSpeed <= 10

        // Generate warnings
        var warnings: [WeatherWarning] = []
        if weatherData.windSpeed > 10 {
            warnings.append(.windSpeed(weatherData.windSpeed))
        }
        if weatherData.temperature > 85 || weatherData.temperature < 50 {
            warnings.append(.temperature(weatherData.temperature))
        }
        if weatherData.precipitationProbability > 30 {
            warnings.append(.precipitation(weatherData.precipitationProbability))
        }
        if weatherData.uvIndex > 7 {
            warnings.append(.uvIndex(weatherData.uvIndex))
        }
        self.warnings = warnings

        // Generate recommendations
        var recommendations: [String] = []
        if weatherData.windSpeed > 10 {
            recommendations.append("Use low-drift nozzles and reduce pressure")
        }
        if weatherData.temperature > 80 {
            recommendations.append("Schedule treatments for early morning or evening")
        }
        if weatherData.precipitationProbability > 20 {
            recommendations.append("Monitor radar and be prepared to stop treatment")
        }
        if weatherData.uvIndex > 6 {
            recommendations.append("Ensure technician uses sun protection")
        }
        self.recommendations = recommendations

        // Time window recommendation
        if overallSafety == .caution {
            if weatherData.temperature > 80 {
                self.recommendedTimeWindow = .earlyMorning
            } else if weatherData.windSpeed > 10 {
                self.recommendedTimeWindow = .calmerPeriod
            } else {
                self.recommendedTimeWindow = nil
            }
        } else {
            self.recommendedTimeWindow = nil
        }
    }
}

enum SafetyLevel: String, Codable, CaseIterable {
    case optimal = "Optimal"
    case acceptable = "Acceptable"
    case caution = "Caution"
    case unsafe = "Unsafe"

    var color: String {
        switch self {
        case .optimal: return "green"
        case .acceptable: return "yellow"
        case .caution: return "orange"
        case .unsafe: return "red"
        }
    }

    var description: String {
        switch self {
        case .optimal: return "Ideal conditions for all treatments"
        case .acceptable: return "Good conditions with minor limitations"
        case .caution: return "Treatment possible with precautions"
        case .unsafe: return "Do not perform treatments"
        }
    }
}

enum TimeWindow: String, Codable {
    case earlyMorning = "Early Morning (6-9 AM)"
    case midMorning = "Mid Morning (9-11 AM)"
    case lateEvening = "Late Evening (6-8 PM)"
    case calmerPeriod = "Wait for calmer conditions"
}

enum WeatherWarning: Codable, Equatable {
    case windSpeed(Double)
    case temperature(Double)
    case precipitation(Int)
    case uvIndex(Double)
    case visibility(Double)

    var title: String {
        switch self {
        case .windSpeed: return "High Wind Speed"
        case .temperature: return "Temperature Concern"
        case .precipitation: return "Precipitation Risk"
        case .uvIndex: return "High UV Index"
        case .visibility: return "Poor Visibility"
        }
    }

    var description: String {
        switch self {
        case .windSpeed(let speed):
            return "Wind speed: \(Int(speed)) mph"
        case .temperature(let temp):
            return "Temperature: \(Int(temp))°F"
        case .precipitation(let prob):
            return "Rain probability: \(prob)%"
        case .uvIndex(let index):
            return "UV Index: \(Int(index))"
        case .visibility(let vis):
            return "Visibility: \(Int(vis/1609)) miles"
        }
    }
}

// MARK: - Core Data Weather Entities

/// Core Data entity for caching weather data
@objc(WeatherDataEntity)
public class WeatherDataEntity: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeatherDataEntity> {
        return NSFetchRequest<WeatherDataEntity>(entityName: "WeatherDataEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var temperature: Double
    @NSManaged public var feelsLike: Double
    @NSManaged public var humidity: Int16
    @NSManaged public var pressure: Double
    @NSManaged public var windSpeed: Double
    @NSManaged public var windDirection: Double
    @NSManaged public var uvIndex: Double
    @NSManaged public var precipitationProbability: Int16
    @NSManaged public var visibility: Double
    @NSManaged public var cloudCover: Int16
    @NSManaged public var condition: String
    @NSManaged public var conditionDescription: String
    @NSManaged public var timestamp: Date
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var isSafeForTreatment: Bool
    @NSManaged public var safetyLevel: String
    @NSManaged public var weatherQualityScore: Double
    @NSManaged public var associatedJobID: UUID?
}

extension WeatherDataEntity : Identifiable {}

/// Core Data entity for weather alerts and notifications
@objc(WeatherAlertEntity)
public class WeatherAlertEntity: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeatherAlertEntity> {
        return NSFetchRequest<WeatherAlertEntity>(entityName: "WeatherAlertEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var alertType: String
    @NSManaged public var title: String
    @NSManaged public var message: String
    @NSManaged public var priority: String
    @NSManaged public var timestamp: Date
    @NSManaged public var isRead: Bool
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var expirationDate: Date?
}

extension WeatherAlertEntity : Identifiable {}

/// Core Data entity for weather forecast data
@objc(WeatherForecastEntity)
public class WeatherForecastEntity: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeatherForecastEntity> {
        return NSFetchRequest<WeatherForecastEntity>(entityName: "WeatherForecastEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var forecastDate: Date
    @NSManaged public var temperature: Double
    @NSManaged public var humidity: Int16
    @NSManaged public var windSpeed: Double
    @NSManaged public var precipitationProbability: Int16
    @NSManaged public var condition: String
    @NSManaged public var conditionDescription: String
    @NSManaged public var createdAt: Date
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
}

extension WeatherForecastEntity : Identifiable {}

// MARK: - Chemical Management Models

/// Represents a chemical product used in pest control treatments
struct Chemical: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var activeIngredient: String
    var manufacturerName: String
    var epaRegistrationNumber: String
    var concentration: Double
    var unitOfMeasure: String
    var quantityInStock: Double
    var expirationDate: Date
    var batchNumber: String?
    var targetPests: [String]
    var signalWord: SignalWord
    var hazardCategory: HazardCategory
    var pphiDays: Int // Pre-harvest interval in days
    var reentryInterval: Int // In hours
    var siteOfAction: String
    var storageRequirements: String
    var createdDate: Date
    var lastModified: Date

    /// Checks if chemical is expired
    var isExpired: Bool {
        return expirationDate < Date()
    }

    /// Checks if chemical is near expiration (within 30 days)
    var isNearExpiration: Bool {
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return expirationDate <= thirtyDaysFromNow && !isExpired
    }

    /// Checks if chemical quantity is low (less than 10% of typical stock)
    var isLowStock: Bool {
        return quantityInStock < 10.0 // This could be made configurable
    }

    /// Formatted quantity display
    var quantityFormatted: String {
        return String(format: "%.2f %@", quantityInStock, unitOfMeasure)
    }

    /// Formatted concentration display
    var concentrationFormatted: String {
        return String(format: "%.1f%%", concentration)
    }

    init(id: UUID = UUID(), name: String, activeIngredient: String, manufacturerName: String,
         epaRegistrationNumber: String, concentration: Double, unitOfMeasure: String,
         quantityInStock: Double, expirationDate: Date, batchNumber: String? = nil,
         targetPests: [String] = [], signalWord: SignalWord = .caution,
         hazardCategory: HazardCategory = .category3, pphiDays: Int = 0, reentryInterval: Int = 0,
         siteOfAction: String = "", storageRequirements: String = "",
         createdDate: Date = Date(), lastModified: Date = Date()) {
        self.id = id
        self.name = name
        self.activeIngredient = activeIngredient
        self.manufacturerName = manufacturerName
        self.epaRegistrationNumber = epaRegistrationNumber
        self.concentration = concentration
        self.unitOfMeasure = unitOfMeasure
        self.quantityInStock = quantityInStock
        self.expirationDate = expirationDate
        self.batchNumber = batchNumber
        self.targetPests = targetPests
        self.signalWord = signalWord
        self.hazardCategory = hazardCategory
        self.pphiDays = pphiDays
        self.reentryInterval = reentryInterval
        self.siteOfAction = siteOfAction
        self.storageRequirements = storageRequirements
        self.createdDate = createdDate
        self.lastModified = lastModified
    }
}

/// EPA signal word classification for chemical hazards
enum SignalWord: String, CaseIterable, Codable, Identifiable {
    case danger = "DANGER"
    case warning = "WARNING"
    case caution = "CAUTION"

    var id: String { rawValue }

    var color: String {
        switch self {
        case .danger: return "red"
        case .warning: return "orange"
        case .caution: return "yellow"
        }
    }

    var description: String {
        switch self {
        case .danger: return "Highly toxic - extreme caution required"
        case .warning: return "Moderately toxic - use with care"
        case .caution: return "Slightly toxic - follow label directions"
        }
    }
}

/// EPA toxicity category classification
enum HazardCategory: String, CaseIterable, Codable, Identifiable {
    case category1 = "Category I"
    case category2 = "Category II"
    case category3 = "Category III"
    case category4 = "Category IV"

    var id: String { rawValue }

    var riskLevel: String {
        switch self {
        case .category1: return "High Risk"
        case .category2: return "Moderate Risk"
        case .category3: return "Low Risk"
        case .category4: return "Minimal Risk"
        }
    }

    var requiredPPE: [String] {
        switch self {
        case .category1:
            return ["Respirator", "Chemical-resistant gloves", "Protective suit", "Eye protection"]
        case .category2:
            return ["Chemical-resistant gloves", "Long sleeves", "Eye protection"]
        case .category3:
            return ["Chemical-resistant gloves", "Long sleeves"]
        case .category4:
            return ["Basic protective clothing"]
        }
    }
}

/// Represents a chemical treatment application record
struct ChemicalTreatment: Identifiable, Codable, Equatable {
    let id: UUID
    var jobId: UUID
    var chemicalId: UUID
    var applicatorName: String
    var applicationDate: Date
    var applicationMethod: ApplicationMethod
    var targetPests: [String]
    var treatmentLocation: String
    var areaTreated: Double // in square feet
    var quantityUsed: Double
    var dosageRate: Double // active ingredient per unit area
    var concentrationUsed: Double
    var dilutionRatio: String
    var weatherConditions: WeatherSnapshot?
    var environmentalConditions: String
    var notes: String?
    var createdDate: Date
    var lastModified: Date

    /// Calculated total active ingredient applied
    var totalActiveIngredientApplied: Double {
        return quantityUsed * (concentrationUsed / 100.0)
    }

    /// Formatted area treated display
    var areaTreatedFormatted: String {
        if areaTreated >= 43560 { // 1 acre = 43,560 sq ft
            let acres = areaTreated / 43560
            return String(format: "%.2f acres", acres)
        } else {
            return String(format: "%.0f sq ft", areaTreated)
        }
    }

    /// Formatted quantity used display
    var quantityUsedFormatted: String {
        return String(format: "%.2f units", quantityUsed)
    }

    /// Formatted dosage rate display
    var dosageRateFormatted: String {
        return String(format: "%.2f units/1000 sq ft", dosageRate)
    }

    init(id: UUID = UUID(), jobId: UUID, chemicalId: UUID, applicatorName: String,
         applicationDate: Date = Date(), applicationMethod: ApplicationMethod,
         targetPests: [String] = [], treatmentLocation: String, areaTreated: Double,
         quantityUsed: Double, dosageRate: Double, concentrationUsed: Double,
         dilutionRatio: String = "1:1", weatherConditions: WeatherSnapshot? = nil,
         environmentalConditions: String = "", notes: String? = nil,
         createdDate: Date = Date(), lastModified: Date = Date()) {
        self.id = id
        self.jobId = jobId
        self.chemicalId = chemicalId
        self.applicatorName = applicatorName
        self.applicationDate = applicationDate
        self.applicationMethod = applicationMethod
        self.targetPests = targetPests
        self.treatmentLocation = treatmentLocation
        self.areaTreated = areaTreated
        self.quantityUsed = quantityUsed
        self.dosageRate = dosageRate
        self.concentrationUsed = concentrationUsed
        self.dilutionRatio = dilutionRatio
        self.weatherConditions = weatherConditions
        self.environmentalConditions = environmentalConditions
        self.notes = notes
        self.createdDate = createdDate
        self.lastModified = lastModified
    }
}

/// Application methods for chemical treatments
enum ApplicationMethod: String, CaseIterable, Codable, Identifiable {
    case spray = "Spray"
    case bait = "Bait"
    case dust = "Dust"
    case granular = "Granular"
    case fogger = "Fogger"
    case injection = "Injection"
    case paint = "Paint/Brush"
    case aerosol = "Aerosol"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .spray: return "Liquid spray application"
        case .bait: return "Bait station or gel bait"
        case .dust: return "Dust formulation"
        case .granular: return "Granular application"
        case .fogger: return "Fogging or misting"
        case .injection: return "Direct injection"
        case .paint: return "Paint or brush application"
        case .aerosol: return "Aerosol spray"
        }
    }

    var equipmentRequired: [String] {
        switch self {
        case .spray: return ["Sprayer", "Nozzles", "Pressure tank"]
        case .bait: return ["Bait gun", "Bait stations"]
        case .dust: return ["Duster", "Dust applicator"]
        case .granular: return ["Spreader", "Granular applicator"]
        case .fogger: return ["Fogger", "ULV equipment"]
        case .injection: return ["Injection equipment", "Drill"]
        case .paint: return ["Brushes", "Paint applicator"]
        case .aerosol: return ["Aerosol cans", "Extension wand"]
        }
    }
}

// MARK: - Chemical Dosage Calculator Models

/// Dosage calculation parameters and results
struct DosageCalculation: Codable, Equatable {
    let chemicalId: UUID
    let targetArea: Double // in square feet
    let targetPest: String
    let applicationMethod: ApplicationMethod
    let labelRate: Double // recommended rate from label
    let calculatedQuantity: Double // total quantity needed
    let dilutionRatio: String
    let mixingInstructions: String
    let safetyNotes: [String]
    let calculatedAt: Date

    /// Formatted target area display
    var targetAreaFormatted: String {
        if targetArea >= 43560 {
            let acres = targetArea / 43560
            return String(format: "%.2f acres", acres)
        } else {
            return String(format: "%.0f sq ft", targetArea)
        }
    }

    /// Formatted quantity display
    var calculatedQuantityFormatted: String {
        return String(format: "%.2f units", calculatedQuantity)
    }
}

// MARK: - Core Data Extensions
// Note: Core Data entities are auto-generated from the .xcdatamodeld file
// Extensions and helper methods are defined here

// MARK: - Equipment Management Models

/// Comprehensive equipment model for pest control operations
struct Equipment: Identifiable, Codable {
    let id: UUID
    var name: String
    var brand: String
    var model: String
    var serialNumber: String
    var type: EquipmentType
    var category: EquipmentCategory
    var status: EquipmentStatus
    var qrCodeValue: String?
    var purchaseDate: Date
    var warrantyExpiration: Date?
    var lastInspectionDate: Date?
    var nextMaintenanceDate: Date?
    var lastCalibrationDate: Date?
    var nextCalibrationDate: Date?
    var currentLocation: String?
    var assignedTechnicianId: String?
    var specifications: EquipmentSpecifications
    var maintenanceHistory: [MaintenanceRecord]
    var inspectionHistory: [InspectionRecord]
    var calibrationHistory: [CalibrationRecord]
    var usageLog: [UsageRecord]
    var notes: String?
    var createdDate: Date
    var lastModified: Date

    // Usage tracking properties
    var totalUsageHours: Double
    var lastUsageDate: Date?

    /// Equipment is due for maintenance
    var isMaintenanceDue: Bool {
        guard let nextMaintenance = nextMaintenanceDate else { return false }
        return nextMaintenance <= Date()
    }

    /// Equipment is overdue for maintenance
    var isMaintenanceOverdue: Bool {
        guard let nextMaintenance = nextMaintenanceDate else { return false }
        return nextMaintenance < Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    /// Equipment needs calibration
    var isCalibrationDue: Bool {
        guard let nextCalibration = nextCalibrationDate else { return false }
        return nextCalibration <= Date()
    }

    /// Equipment is available for assignment
    var isAvailable: Bool {
        return status == .available && !isMaintenanceDue && !isCalibrationDue
    }

    /// Total operating hours
    var totalOperatingHours: Double {
        return usageLog.reduce(0) { $0 + $1.hours }
    }

    /// Days since last inspection
    var daysSinceLastInspection: Int {
        guard let lastInspection = lastInspectionDate else { return Int.max }
        return Calendar.current.dateComponents([.day], from: lastInspection, to: Date()).day ?? Int.max
    }

    init(id: UUID = UUID(), name: String, brand: String, model: String, serialNumber: String,
         type: EquipmentType, category: EquipmentCategory = .sprayEquipment,
         purchaseDate: Date = Date(), specifications: EquipmentSpecifications = EquipmentSpecifications()) {
        self.id = id
        self.name = name
        self.brand = brand
        self.model = model
        self.serialNumber = serialNumber
        self.type = type
        self.category = category
        self.status = .available
        self.purchaseDate = purchaseDate
        self.specifications = specifications
        self.maintenanceHistory = []
        self.inspectionHistory = []
        self.calibrationHistory = []
        self.usageLog = []
        self.createdDate = Date()
        self.lastModified = Date()
        self.totalUsageHours = 0
        self.lastUsageDate = nil
    }
}

/// Equipment type enumeration
enum EquipmentType: String, CaseIterable, Codable, Identifiable {
    case backpackSprayer = "backpack_sprayer"
    case tankSprayer = "tank_sprayer"
    case handSprayer = "hand_sprayer"
    case airlessSprayRig = "airless_spray_rig"
    case fogger = "fogger"
    case duster = "duster"
    case granularSpreader = "granular_spreader"
    case moistureMeter = "moisture_meter"
    case thermometer = "thermometer"
    case borescope = "borescope"
    case drill = "drill"
    case ladder = "ladder"
    case safetyEquipment = "safety_equipment"
    case baitGun = "bait_gun"
    case vacuumSystem = "vacuum_system"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backpackSprayer: return "Backpack Sprayer"
        case .tankSprayer: return "Tank Sprayer"
        case .handSprayer: return "Hand Sprayer"
        case .airlessSprayRig: return "Airless Spray Rig"
        case .fogger: return "Fogger"
        case .duster: return "Duster"
        case .granularSpreader: return "Granular Spreader"
        case .moistureMeter: return "Moisture Meter"
        case .thermometer: return "Thermometer"
        case .borescope: return "Borescope"
        case .drill: return "Drill"
        case .ladder: return "Ladder"
        case .safetyEquipment: return "Safety Equipment"
        case .baitGun: return "Bait Gun"
        case .vacuumSystem: return "Vacuum System"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .backpackSprayer, .tankSprayer, .handSprayer, .airlessSprayRig: return "drop.fill"
        case .fogger: return "cloud.fill"
        case .duster: return "wind"
        case .granularSpreader: return "circle.dotted"
        case .moistureMeter: return "humidity.fill"
        case .thermometer: return "thermometer"
        case .borescope: return "eye.fill"
        case .drill: return "bolt.fill"
        case .ladder: return "ladder"
        case .safetyEquipment: return "shield.fill"
        case .baitGun: return "target"
        case .vacuumSystem: return "tornado"
        case .other: return "wrench.and.screwdriver"
        }
    }

    var requiresCalibration: Bool {
        switch self {
        case .moistureMeter, .thermometer, .backpackSprayer, .tankSprayer, .airlessSprayRig, .granularSpreader:
            return true
        default:
            return false
        }
    }

    var maintenanceIntervalDays: Int {
        switch self {
        case .backpackSprayer, .handSprayer: return 30
        case .tankSprayer, .airlessSprayRig: return 60
        case .fogger, .duster: return 45
        case .granularSpreader: return 90
        case .moistureMeter, .thermometer, .borescope: return 180
        case .drill: return 120
        case .ladder: return 365
        case .safetyEquipment: return 180
        case .baitGun: return 90
        case .vacuumSystem: return 60
        case .other: return 90
        }
    }
}

/// Equipment category for grouping
enum EquipmentCategory: String, CaseIterable, Codable, Identifiable {
    case sprayEquipment = "spray_equipment"
    case detectionTools = "detection_tools"
    case safetyGear = "safety_gear"
    case applicationTools = "application_tools"
    case maintenanceTools = "maintenance_tools"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sprayEquipment: return "Spray Equipment"
        case .detectionTools: return "Detection Tools"
        case .safetyGear: return "Safety Gear"
        case .applicationTools: return "Application Tools"
        case .maintenanceTools: return "Maintenance Tools"
        }
    }
}

/// Equipment status enumeration
enum EquipmentStatus: String, CaseIterable, Codable, Identifiable {
    case available = "available"
    case inUse = "in_use"
    case maintenance = "maintenance"
    case repair = "repair"
    case calibration = "calibration"
    case retired = "retired"
    case lost = "lost"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .available: return "Available"
        case .inUse: return "In Use"
        case .maintenance: return "Maintenance"
        case .repair: return "Repair"
        case .calibration: return "Calibration"
        case .retired: return "Retired"
        case .lost: return "Lost"
        }
    }

    var color: Color {
        switch self {
        case .available: return .green
        case .inUse: return .blue
        case .maintenance: return .orange
        case .repair: return .red
        case .calibration: return .purple
        case .retired: return .gray
        case .lost: return .black
        }
    }
}

/// Equipment specifications
struct EquipmentSpecifications: Codable {
    var tankCapacity: Double? // in gallons or liters
    var maxPressure: Double? // in PSI
    var powerSource: String? // electric, battery, manual, gas
    var weight: Double? // in pounds
    var dimensions: String? // LxWxH
    var flowRate: Double? // gallons per minute
    var operatingTemperature: String? // temperature range
    var accuracy: String? // for measuring devices
    var batteryLife: Double? // in hours
    var warrantyPeriod: String?
    var additionalSpecs: [String: String]

    init() {
        self.additionalSpecs = [:]
    }
}

/// Maintenance record
struct MaintenanceRecord: Identifiable, Codable {
    let id: UUID
    var equipmentId: UUID
    var type: MaintenanceType
    var description: String
    var performedBy: String
    var performedDate: Date
    var scheduledDate: Date?
    var duration: Double // in hours
    var cost: Double
    var partsReplaced: [String]
    var serviceNotes: String?
    var nextServiceDate: Date?
    var status: MaintenanceStatus
    var priority: MaintenancePriority
    var photos: [String] // photo file paths
    var createdDate: Date

    init(equipmentId: UUID, type: MaintenanceType, description: String, performedBy: String) {
        self.id = UUID()
        self.equipmentId = equipmentId
        self.type = type
        self.description = description
        self.performedBy = performedBy
        self.performedDate = Date()
        self.duration = 0
        self.cost = 0
        self.partsReplaced = []
        self.status = .completed
        self.priority = .medium
        self.photos = []
        self.createdDate = Date()
    }
}

/// Maintenance status
enum MaintenanceStatus: String, CaseIterable, Codable {
    case scheduled = "scheduled"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case delayed = "delayed"

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .delayed: return "Delayed"
        }
    }
}

/// Equipment inspection record
struct InspectionRecord: Identifiable, Codable {
    let id: UUID
    var equipmentId: UUID
    var inspectorId: String
    var inspectorName: String
    var inspectionDate: Date
    var inspectionType: InspectionType
    var template: String
    var result: InspectionResult
    var score: Double // 0-100
    var passed: Bool
    var sections: [InspectionSectionResult]
    var photos: [String] // photo file paths
    var notes: String?
    var actionItems: [ActionItem]
    var nextInspectionDate: Date?
    var createdDate: Date

    init(equipmentId: UUID, inspectorId: String, inspectorName: String, template: String) {
        self.id = UUID()
        self.equipmentId = equipmentId
        self.inspectorId = inspectorId
        self.inspectorName = inspectorName
        self.inspectionDate = Date()
        self.inspectionType = .routine
        self.template = template
        self.result = .pending
        self.score = 0
        self.passed = false
        self.sections = []
        self.photos = []
        self.actionItems = []
        self.createdDate = Date()
    }
}

/// Inspection type
enum InspectionType: String, CaseIterable, Codable {
    case routine = "routine"
    case preUse = "pre_use"
    case postUse = "post_use"
    case safety = "safety"
    case regulatory = "regulatory"
    case damage = "damage"

    var displayName: String {
        switch self {
        case .routine: return "Routine Inspection"
        case .preUse: return "Pre-Use Check"
        case .postUse: return "Post-Use Check"
        case .safety: return "Safety Inspection"
        case .regulatory: return "Regulatory Inspection"
        case .damage: return "Damage Assessment"
        }
    }
}

/// Inspection result
enum InspectionResult: String, CaseIterable, Codable {
    case pending = "pending"
    case passed = "passed"
    case failed = "failed"
    case conditionalPass = "conditional_pass"
    case needsCalibration = "needs_calibration"
    case needsMaintenance = "needs_maintenance"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .passed: return "Passed"
        case .failed: return "Failed"
        case .conditionalPass: return "Conditional Pass"
        case .needsCalibration: return "Needs Calibration"
        case .needsMaintenance: return "Needs Maintenance"
        }
    }

    var color: String {
        switch self {
        case .pending: return "gray"
        case .passed: return "green"
        case .failed: return "red"
        case .conditionalPass: return "orange"
        case .needsCalibration: return "yellow"
        case .needsMaintenance: return "orange"
        }
    }
}

/// Inspection section result
struct InspectionSectionResult: Identifiable, Codable {
    let id: UUID
    var sectionName: String
    var items: [InspectionItemResult]
    var passed: Bool
    var score: Double
    var notes: String?

    init(sectionName: String) {
        self.id = UUID()
        self.sectionName = sectionName
        self.items = []
        self.passed = false
        self.score = 0
    }
}

/// Inspection item result
struct InspectionItemResult: Identifiable, Codable {
    let id: UUID
    var itemName: String
    var status: InspectionItemStatus
    var notes: String?
    var isRequired: Bool
    var weight: Double // scoring weight

    init(itemName: String, isRequired: Bool = true, weight: Double = 1.0) {
        self.id = UUID()
        self.itemName = itemName
        self.status = .pending
        self.isRequired = isRequired
        self.weight = weight
    }
}

/// Inspection item status
enum InspectionItemStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case passed = "passed"
    case failed = "failed"
    case notApplicable = "not_applicable"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .passed: return "Passed"
        case .failed: return "Failed"
        case .notApplicable: return "N/A"
        }
    }
}

/// Action item from inspection
struct ActionItem: Identifiable, Codable {
    let id: UUID
    var description: String
    var priority: ActionItemPriority
    var dueDate: Date?
    var assignedTo: String?
    var status: ActionItemStatus
    var completedDate: Date?
    var notes: String?

    init(description: String, priority: ActionItemPriority = .medium) {
        self.id = UUID()
        self.description = description
        self.priority = priority
        self.status = .open
    }
}

/// Action item priority
enum ActionItemPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

/// Action item status
enum ActionItemStatus: String, CaseIterable, Codable {
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

/// Calibration record
struct CalibrationRecord: Identifiable, Codable {
    let id: UUID
    var equipmentId: UUID
    var calibratedBy: String
    var calibrationDate: Date
    var calibrationType: CalibrationType
    var standardUsed: String? // reference standard or device
    var preCalibrationReadings: [CalibrationReading]
    var postCalibrationReadings: [CalibrationReading]
    var adjustmentsMade: String?
    var result: CalibrationResult
    var tolerance: Double
    var accuracy: Double
    var certificateNumber: String?
    var nextCalibrationDate: Date
    var notes: String?
    var environmentalConditions: EnvironmentalConditions?
    var createdDate: Date

    init(equipmentId: UUID, calibratedBy: String, calibrationType: CalibrationType) {
        self.id = UUID()
        self.equipmentId = equipmentId
        self.calibratedBy = calibratedBy
        self.calibrationDate = Date()
        self.calibrationType = calibrationType
        self.preCalibrationReadings = []
        self.postCalibrationReadings = []
        self.result = .pending
        self.tolerance = 0
        self.accuracy = 0
        self.nextCalibrationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        self.createdDate = Date()
    }
}

/// Calibration type
enum CalibrationType: String, CaseIterable, Codable {
    case flow = "flow"
    case pressure = "pressure"
    case volume = "volume"
    case temperature = "temperature"
    case humidity = "humidity"
    case electrical = "electrical"
    case dimensional = "dimensional"

    var displayName: String {
        switch self {
        case .flow: return "Flow Rate"
        case .pressure: return "Pressure"
        case .volume: return "Volume"
        case .temperature: return "Temperature"
        case .humidity: return "Humidity"
        case .electrical: return "Electrical"
        case .dimensional: return "Dimensional"
        }
    }
}

/// Calibration result
enum CalibrationResult: String, CaseIterable, Codable {
    case pending = "pending"
    case passed = "passed"
    case failed = "failed"
    case adjusted = "adjusted"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .passed: return "Passed"
        case .failed: return "Failed"
        case .adjusted: return "Adjusted"
        }
    }

    var color: String {
        switch self {
        case .pending: return "gray"
        case .passed: return "green"
        case .failed: return "red"
        case .adjusted: return "orange"
        }
    }
}

/// Calibration reading
struct CalibrationReading: Identifiable, Codable {
    let id: UUID
    var parameter: String
    var expectedValue: Double
    var actualValue: Double
    var unit: String
    var deviation: Double
    var withinTolerance: Bool

    init(parameter: String, expectedValue: Double, actualValue: Double, unit: String, tolerance: Double) {
        self.id = UUID()
        self.parameter = parameter
        self.expectedValue = expectedValue
        self.actualValue = actualValue
        self.unit = unit
        self.deviation = abs(expectedValue - actualValue)
        self.withinTolerance = self.deviation <= tolerance
    }
}

/// Environmental conditions during calibration
struct EnvironmentalConditions: Codable {
    var temperature: Double
    var humidity: Double
    var pressure: Double
    var location: String?

    init(temperature: Double, humidity: Double, pressure: Double, location: String? = nil) {
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.location = location
    }
}

/// Equipment usage record
struct UsageRecord: Identifiable, Codable {
    let id: UUID
    var equipmentId: UUID
    var operatorId: String
    var operatorName: String
    var jobId: UUID?
    var startTime: Date
    var endTime: Date?
    var hours: Double
    var location: String?
    var chemicalUsed: String?
    var areaTreated: Double? // square feet
    var conditions: UsageConditions?
    var notes: String?
    var createdDate: Date

    /// Duration in hours
    var duration: Double {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime) / 3600
        }
        return endTime.timeIntervalSince(startTime) / 3600
    }

    init(equipmentId: UUID, operatorId: String, operatorName: String) {
        self.id = UUID()
        self.equipmentId = equipmentId
        self.operatorId = operatorId
        self.operatorName = operatorName
        self.startTime = Date()
        self.hours = 0
        self.createdDate = Date()
    }
}

// MARK: - Core Data Equipment Extensions
// Note: Core Data entities are auto-generated from the .xcdatamodeld file
// Extensions and helper methods are defined here

// MARK: - Sync Status Enum
enum SyncStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
    case conflict = "conflict"

    var displayName: String {
        switch self {
        case .pending: return "Pending Sync"
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .failed: return "Sync Failed"
        case .conflict: return "Sync Conflict"
        }
    }
}

// MARK: - Equipment Maintenance Enums (moved from EquipmentPerformanceManager for shared access)

/// Maintenance type enumeration
enum MaintenanceType: String, CaseIterable, Codable {
    case routine = "routine"
    case preventive = "preventive"
    case corrective = "corrective"
    case emergency = "emergency"
    case calibration = "calibration"

    var description: String {
        switch self {
        case .routine: return "Routine Maintenance"
        case .preventive: return "Preventive Maintenance"
        case .corrective: return "Corrective Maintenance"
        case .emergency: return "Emergency Repair"
        case .calibration: return "Calibration"
        }
    }
}

/// Maintenance priority enumeration
enum MaintenancePriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"

    var description: String {
        switch self {
        case .low: return "Low Priority"
        case .medium: return "Medium Priority"
        case .high: return "High Priority"
        case .urgent: return "Urgent"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}

/// Usage conditions affecting equipment performance
struct UsageConditions: Codable {
    let temperature: Double?
    let humidity: Double?
    let terrain: String?
    let chemicalType: String?
    let workload: WorkloadLevel
}

/// Workload intensity levels
enum WorkloadLevel: Int, CaseIterable, Codable {
    case light = 1
    case moderate = 2
    case heavy = 3
    case extreme = 4

    var description: String {
        switch self {
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .extreme: return "Extreme"
        }
    }
}

// MARK: - Equipment Inspection and Usage Models

/// Equipment inspection record
struct EquipmentInspection: Identifiable, Codable, Equatable {
    let id: UUID
    let equipmentId: UUID
    let inspectorName: String
    let inspectionType: EquipmentInspectionType
    let result: InspectionResult
    let notes: String
    let inspectionDate: Date

    init(id: UUID = UUID(), equipmentId: UUID, inspectorName: String, inspectionType: EquipmentInspectionType, result: InspectionResult, notes: String, inspectionDate: Date) {
        self.id = id
        self.equipmentId = equipmentId
        self.inspectorName = inspectorName
        self.inspectionType = inspectionType
        self.result = result
        self.notes = notes
        self.inspectionDate = inspectionDate
    }
}

/// Types of equipment inspections
enum EquipmentInspectionType: String, CaseIterable, Codable {
    case preService = "pre_service"
    case postService = "post_service"
    case routine = "routine"
    case calibration = "calibration"
    case maintenance = "maintenance"
    case safety = "safety"

    var displayName: String {
        switch self {
        case .preService: return "Pre-Service Check"
        case .postService: return "Post-Service Check"
        case .routine: return "Routine Inspection"
        case .calibration: return "Calibration Check"
        case .maintenance: return "Maintenance Check"
        case .safety: return "Safety Inspection"
        }
    }
}

/// Equipment usage record for job tracking
struct EquipmentUsageRecord: Identifiable, Codable {
    let id: UUID
    let equipmentId: UUID
    let jobId: UUID
    let technicianName: String
    let usageType: EquipmentUsageType
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let notes: String

    init(id: UUID = UUID(), equipmentId: UUID, jobId: UUID, technicianName: String, usageType: EquipmentUsageType, startTime: Date, endTime: Date, duration: TimeInterval, notes: String) {
        self.id = id
        self.equipmentId = equipmentId
        self.jobId = jobId
        self.technicianName = technicianName
        self.usageType = usageType
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.notes = notes
    }
}

/// Types of equipment usage
enum EquipmentUsageType: String, CaseIterable, Codable {
    case spraying = "spraying"
    case inspection = "inspection"
    case measurement = "measurement"
    case calibration = "calibration"
    case cleaning = "cleaning"
    case transport = "transport"

    var displayName: String {
        switch self {
        case .spraying: return "Chemical Application"
        case .inspection: return "Property Inspection"
        case .measurement: return "Measurement/Testing"
        case .calibration: return "Calibration"
        case .cleaning: return "Equipment Cleaning"
        case .transport: return "Transport/Setup"
        }
    }
}

/// Pre-service checklist item
struct PreServiceChecklistItem: Identifiable, Codable {
    let id: UUID
    let equipmentId: UUID
    let itemName: String
    let description: String
    let isRequired: Bool
    let category: ChecklistCategory
    var isCompleted: Bool
    var completedBy: String?
    var completedDate: Date?
    var notes: String?

    enum ChecklistCategory: String, CaseIterable, Codable {
        case visual = "visual"
        case functional = "functional"
        case safety = "safety"
        case calibration = "calibration"
        case maintenance = "maintenance"

        var displayName: String {
            switch self {
            case .visual: return "Visual Inspection"
            case .functional: return "Functional Test"
            case .safety: return "Safety Check"
            case .calibration: return "Calibration Verification"
            case .maintenance: return "Maintenance Check"
            }
        }

        var color: String {
            switch self {
            case .visual: return "blue"
            case .functional: return "green"
            case .safety: return "red"
            case .calibration: return "orange"
            case .maintenance: return "purple"
            }
        }
    }

    init(id: UUID = UUID(), equipmentId: UUID, itemName: String, description: String, isRequired: Bool = true, category: ChecklistCategory, isCompleted: Bool = false) {
        self.id = id
        self.equipmentId = equipmentId
        self.itemName = itemName
        self.description = description
        self.isRequired = isRequired
        self.category = category
        self.isCompleted = isCompleted
    }
}

/// Pre-service checklist for equipment
struct PreServiceChecklist: Identifiable, Codable {
    let id: UUID
    let technicianId: String
    let technicianName: String
    let checklistDate: Date
    var items: [PreServiceChecklistItem]
    var isCompleted: Bool
    var completedDate: Date?
    var supervisorApproval: Bool
    var approvedBy: String?
    var approvalDate: Date?

    /// Completion percentage
    var completionPercentage: Double {
        guard !items.isEmpty else { return 0.0 }
        let completedCount = items.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(items.count) * 100.0
    }

    /// All required items completed
    var allRequiredItemsCompleted: Bool {
        let requiredItems = items.filter { $0.isRequired }
        return requiredItems.allSatisfy { $0.isCompleted }
    }

    /// Items that need attention
    var itemsNeedingAttention: [PreServiceChecklistItem] {
        return items.filter { !$0.isCompleted && $0.isRequired }
    }

    init(id: UUID = UUID(), technicianId: String, technicianName: String, checklistDate: Date = Date(), items: [PreServiceChecklistItem] = []) {
        self.id = id
        self.technicianId = technicianId
        self.technicianName = technicianName
        self.checklistDate = checklistDate
        self.items = items
        self.isCompleted = false
        self.supervisorApproval = false
    }
}

// MARK: - Chemical Inventory Management Models

/// Reasons for manual inventory adjustments
enum InventoryAdjustmentReason: String, CaseIterable, Codable {
    case restock = "restock"
    case spillage = "spillage"
    case damage = "damage"
    case transfer = "transfer"
    case correction = "correction"
    case `return` = "return"
    case disposal = "disposal"
    case calibration = "calibration"

    var displayName: String {
        switch self {
        case .restock: return "Restock/Delivery"
        case .spillage: return "Spillage"
        case .damage: return "Damage/Loss"
        case .transfer: return "Transfer to/from truck"
        case .correction: return "Inventory Correction"
        case .`return`: return "Return to Supplier"
        case .disposal: return "Proper Disposal"
        case .calibration: return "Calibration/Testing"
        }
    }

    var isPositiveAdjustment: Bool {
        switch self {
        case .restock, .transfer, .correction:
            return true
        case .spillage, .damage, .`return`, .disposal, .calibration:
            return false
        }
    }
}

/// Record of inventory adjustments
struct InventoryAdjustment: Identifiable, Codable {
    let id: UUID
    let chemicalId: UUID
    let adjustmentAmount: Double
    let reason: InventoryAdjustmentReason
    let notes: String
    let technicianName: String
    let timestamp: Date

    init(id: UUID = UUID(), chemicalId: UUID, adjustmentAmount: Double, reason: InventoryAdjustmentReason, notes: String, technicianName: String, timestamp: Date) {
        self.id = id
        self.chemicalId = chemicalId
        self.adjustmentAmount = adjustmentAmount
        self.reason = reason
        self.notes = notes
        self.technicianName = technicianName
        self.timestamp = timestamp
    }
}

/// Reorder recommendation for low stock chemicals
struct ReorderRecommendation: Identifiable {
    let id: UUID
    let chemical: Chemical
    let recommendedQuantity: Double
    let priority: Priority
    let estimatedDaysUntilEmpty: Int
    let lastOrderDate: Date?
    let averageMonthlyUsage: Double

    enum Priority: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"

        var color: String {
            switch self {
            case .low: return "blue"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }

        var displayName: String {
            switch self {
            case .low: return "Low Priority"
            case .medium: return "Medium Priority"
            case .high: return "High Priority"
            case .critical: return "Critical"
            }
        }
    }

    init(chemical: Chemical, recommendedQuantity: Double, priority: Priority, estimatedDaysUntilEmpty: Int, lastOrderDate: Date? = nil, averageMonthlyUsage: Double = 0.0) {
        self.id = UUID()
        self.chemical = chemical
        self.recommendedQuantity = recommendedQuantity
        self.priority = priority
        self.estimatedDaysUntilEmpty = estimatedDaysUntilEmpty
        self.lastOrderDate = lastOrderDate
        self.averageMonthlyUsage = averageMonthlyUsage
    }
}

/// Chemical usage summary for reporting
struct ChemicalUsageSummary: Identifiable {
    let id: UUID
    let chemical: Chemical
    let totalUsed: Double
    let numberOfApplications: Int
    let averagePerApplication: Double
    let mostRecentApplication: Date?
    let timeframe: TimeframePeriod

    enum TimeframePeriod: String, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case quarterly = "quarterly"
        case yearly = "yearly"

        var displayName: String {
            switch self {
            case .daily: return "Today"
            case .weekly: return "This Week"
            case .monthly: return "This Month"
            case .quarterly: return "This Quarter"
            case .yearly: return "This Year"
            }
        }
    }

    init(chemical: Chemical, totalUsed: Double, numberOfApplications: Int, averagePerApplication: Double, mostRecentApplication: Date?, timeframe: TimeframePeriod) {
        self.id = UUID()
        self.chemical = chemical
        self.totalUsed = totalUsed
        self.numberOfApplications = numberOfApplications
        self.averagePerApplication = averagePerApplication
        self.mostRecentApplication = mostRecentApplication
        self.timeframe = timeframe
    }
}

// MARK: - Emergency Management Models

/// Emergency response contact information
struct EmergencyResponseContact: Identifiable, Codable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let type: EmergencyContactType
    let description: String

    init(id: UUID = UUID(), name: String, phoneNumber: String, type: EmergencyContactType, description: String) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.type = type
        self.description = description
    }
}

/// Types of emergency contacts
enum EmergencyContactType: String, CaseIterable, Codable {
    case emergency911 = "911"
    case poisonControl = "poison_control"
    case companyDispatch = "company_dispatch"
    case supervisor = "supervisor"
    case environmental = "environmental"
    case roadside = "roadside"

    var displayName: String {
        switch self {
        case .emergency911: return "911 Emergency"
        case .poisonControl: return "Poison Control"
        case .companyDispatch: return "Company Dispatch"
        case .supervisor: return "Supervisor"
        case .environmental: return "Environmental"
        case .roadside: return "Roadside Assistance"
        }
    }

    var icon: String {
        switch self {
        case .emergency911: return "phone.fill.badge.plus"
        case .poisonControl: return "cross.case.fill"
        case .companyDispatch: return "antenna.radiowaves.left.and.right"
        case .supervisor: return "person.badge.shield.checkmark"
        case .environmental: return "leaf.fill"
        case .roadside: return "car.fill"
        }
    }
}

/// Emergency incident types
enum EmergencyIncidentType: String, CaseIterable, Codable {
    case chemicalExposure = "chemical_exposure"
    case chemicalSpill = "chemical_spill"
    case medicalEmergency = "medical_emergency"
    case technicianInjury = "technician_injury"
    case equipmentMalfunction = "equipment_malfunction"
    case vehicleBreakdown = "vehicle_breakdown"
    case propertyDamage = "property_damage"
    case customerSafety = "customer_safety"
    case severeInfestation = "severe_infestation"
    case weatherDelay = "weather_delay"
    case accessIssue = "access_issue"
    case epaViolation = "epa_violation"
    case complianceIssue = "compliance_issue"
    case emergencyCall = "emergency_call"

    var displayName: String {
        switch self {
        case .chemicalExposure: return "Chemical Exposure"
        case .chemicalSpill: return "Chemical Spill"
        case .medicalEmergency: return "Medical Emergency"
        case .technicianInjury: return "Technician Injury"
        case .equipmentMalfunction: return "Equipment Malfunction"
        case .vehicleBreakdown: return "Vehicle Breakdown"
        case .propertyDamage: return "Property Damage"
        case .customerSafety: return "Customer Safety Concern"
        case .severeInfestation: return "Severe Infestation"
        case .weatherDelay: return "Weather Delay"
        case .accessIssue: return "Access Issue"
        case .epaViolation: return "EPA Violation"
        case .complianceIssue: return "Compliance Issue"
        case .emergencyCall: return "Emergency Call"
        }
    }

    var icon: String {
        switch self {
        case .chemicalExposure: return "drop.fill"
        case .chemicalSpill: return "exclamationmark.triangle.fill"
        case .medicalEmergency: return "cross.fill"
        case .technicianInjury: return "bandage.fill"
        case .equipmentMalfunction: return "wrench.fill"
        case .vehicleBreakdown: return "car.fill"
        case .propertyDamage: return "house.fill"
        case .customerSafety: return "shield.fill"
        case .severeInfestation: return "ant.fill"
        case .weatherDelay: return "cloud.rain.fill"
        case .accessIssue: return "key.fill"
        case .epaViolation: return "leaf.fill"
        case .complianceIssue: return "checkmark.seal.fill"
        case .emergencyCall: return "phone.fill"
        }
    }

    var category: EmergencyCategory {
        switch self {
        case .chemicalExposure, .chemicalSpill, .medicalEmergency, .technicianInjury:
            return .safety
        case .equipmentMalfunction, .vehicleBreakdown:
            return .operational
        case .propertyDamage, .customerSafety, .severeInfestation, .accessIssue:
            return .customer
        case .weatherDelay:
            return .environmental
        case .epaViolation, .complianceIssue:
            return .compliance
        case .emergencyCall:
            return .communication
        }
    }
}

/// Emergency categories for organization
enum EmergencyCategory: String, CaseIterable, Codable {
    case safety = "safety"
    case operational = "operational"
    case customer = "customer"
    case environmental = "environmental"
    case compliance = "compliance"
    case communication = "communication"

    var displayName: String {
        switch self {
        case .safety: return "Safety Emergencies"
        case .operational: return "Operational Issues"
        case .customer: return "Customer Emergencies"
        case .environmental: return "Environmental"
        case .compliance: return "Compliance & Legal"
        case .communication: return "Emergency Contacts"
        }
    }

    var color: String {
        switch self {
        case .safety: return "red"
        case .operational: return "orange"
        case .customer: return "blue"
        case .environmental: return "green"
        case .compliance: return "purple"
        case .communication: return "gray"
        }
    }
}

/// Emergency severity levels
enum EmergencySeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

/// Emergency incident status
enum EmergencyIncidentStatus: String, CaseIterable, Codable {
    case active = "active"
    case resolved = "resolved"
    case escalated = "escalated"
    case followupRequired = "followup_required"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .resolved: return "Resolved"
        case .escalated: return "Escalated"
        case .followupRequired: return "Follow-up Required"
        }
    }
}

/// Emergency incident record
struct EmergencyIncident: Identifiable, Codable {
    let id: UUID
    let type: EmergencyIncidentType
    let severity: EmergencySeverity
    let title: String
    let description: String
    let latitude: Double?
    let longitude: Double?
    let timestamp: Date
    var status: EmergencyIncidentStatus
    let contactCalled: EmergencyResponseContact?
    let photos: [Data] // Store image data
    let additionalNotes: String

    init(id: UUID = UUID(), type: EmergencyIncidentType, severity: EmergencySeverity, title: String, description: String, location: CLLocation?, timestamp: Date, status: EmergencyIncidentStatus, contactCalled: EmergencyResponseContact?, photos: [UIImage], additionalNotes: String) {
        self.id = id
        self.type = type
        self.severity = severity
        self.title = title
        self.description = description
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        self.timestamp = timestamp
        self.status = status
        self.contactCalled = contactCalled
        self.additionalNotes = additionalNotes

        // Convert UIImages to Data
        self.photos = photos.compactMap { $0.jpegData(compressionQuality: 0.8) }
    }

    // Helper to get location as CLLocation
    var location: CLLocation? {
        guard let latitude = latitude, let longitude = longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    // Helper to get photos as UIImages
    var photosAsImages: [UIImage] {
        return photos.compactMap { UIImage(data: $0) }
    }
}

/// Emergency protocol with step-by-step instructions
struct EmergencyProtocol: Identifiable {
    let id = UUID()
    let title: String
    let steps: [String]
    let criticalContacts: [EmergencyResponseContact]

    init(title: String, steps: [String], criticalContacts: [EmergencyResponseContact]) {
        self.title = title
        self.steps = steps
        self.criticalContacts = criticalContacts
    }
}

// MARK: - Safety Checklist Models

/// Safety checklist categories for technician pre-service checks
enum SafetyChecklistCategory: String, CaseIterable, Codable {
    case personalProtectiveEquipment = "ppe"
    case chemicalSafety = "chemical_safety"
    case equipmentSafety = "equipment_safety"
    case siteSafetyAssessment = "site_safety"
    case healthMedical = "health_medical"
    case regulatoryCompliance = "regulatory"
    case communicationDocumentation = "communication"
    case vehicleTransportation = "vehicle"

    var displayName: String {
        switch self {
        case .personalProtectiveEquipment: return "Personal Protective Equipment"
        case .chemicalSafety: return "Chemical Safety"
        case .equipmentSafety: return "Equipment Safety"
        case .siteSafetyAssessment: return "Site Safety Assessment"
        case .healthMedical: return "Health & Medical"
        case .regulatoryCompliance: return "Regulatory Compliance"
        case .communicationDocumentation: return "Communication & Documentation"
        case .vehicleTransportation: return "Vehicle & Transportation"
        }
    }

    var icon: String {
        switch self {
        case .personalProtectiveEquipment: return "shield.lefthalf.filled"
        case .chemicalSafety: return "drop.triangle"
        case .equipmentSafety: return "wrench.and.screwdriver"
        case .siteSafetyAssessment: return "location.magnifyingglass"
        case .healthMedical: return "cross.case"
        case .regulatoryCompliance: return "checkmark.seal"
        case .communicationDocumentation: return "doc.text"
        case .vehicleTransportation: return "car"
        }
    }

    var color: String {
        switch self {
        case .personalProtectiveEquipment: return "blue"
        case .chemicalSafety: return "red"
        case .equipmentSafety: return "orange"
        case .siteSafetyAssessment: return "green"
        case .healthMedical: return "red"
        case .regulatoryCompliance: return "purple"
        case .communicationDocumentation: return "blue"
        case .vehicleTransportation: return "gray"
        }
    }
}

/// Priority levels for safety checklist items
enum SafetyItemPriority: String, CaseIterable, Codable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "green"
        }
    }
}

/// Individual safety checklist item
struct SafetyChecklistItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let category: SafetyChecklistCategory
    let priority: SafetyItemPriority
    let isRequired: Bool
    let regulatoryRequirement: String?
    var isCompleted: Bool
    var completionTime: Date?
    var notes: String
    var photoRequired: Bool
    var photoData: Data?

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: SafetyChecklistCategory,
        priority: SafetyItemPriority = .medium,
        isRequired: Bool = true,
        regulatoryRequirement: String? = nil,
        photoRequired: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.isRequired = isRequired
        self.regulatoryRequirement = regulatoryRequirement
        self.isCompleted = false
        self.completionTime = nil
        self.notes = ""
        self.photoRequired = photoRequired
        self.photoData = nil
    }

    // Helper to get photo as UIImage
    var photo: UIImage? {
        guard let photoData = photoData else { return nil }
        return UIImage(data: photoData)
    }

    // Helper to set photo from UIImage
    mutating func setPhoto(_ image: UIImage?) {
        self.photoData = image?.jpegData(compressionQuality: 0.8)
    }
}

/// Daily safety checklist completion record
struct SafetyChecklistRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let technicianId: String
    let technicianName: String
    let routeId: String?
    let items: [SafetyChecklistItem]
    let completionTime: Date?
    let isFullyCompleted: Bool
    let criticalItemsCompleted: Bool
    let supervisorOverride: Bool
    let supervisorNotes: String?
    let weatherConditions: String?
    let temperature: Double?
    let workLocation: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        technicianId: String,
        technicianName: String,
        routeId: String? = nil,
        items: [SafetyChecklistItem]
    ) {
        self.id = id
        self.date = date
        self.technicianId = technicianId
        self.technicianName = technicianName
        self.routeId = routeId
        self.items = items
        self.completionTime = nil
        self.supervisorOverride = false
        self.supervisorNotes = nil
        self.weatherConditions = nil
        self.temperature = nil
        self.workLocation = nil

        // Calculate completion status
        let requiredItems = items.filter { $0.isRequired }
        let criticalItems = items.filter { $0.priority == .critical }
        self.isFullyCompleted = requiredItems.allSatisfy { $0.isCompleted }
        self.criticalItemsCompleted = criticalItems.allSatisfy { $0.isCompleted }
    }

    // Statistics helpers
    var completionPercentage: Double {
        let totalItems = items.count
        guard totalItems > 0 else { return 0.0 }
        let completedItems = items.filter { $0.isCompleted }.count
        return Double(completedItems) / Double(totalItems) * 100.0
    }

    var requiredCompletionPercentage: Double {
        let requiredItems = items.filter { $0.isRequired }
        guard !requiredItems.isEmpty else { return 100.0 }
        let completedRequired = requiredItems.filter { $0.isCompleted }.count
        return Double(completedRequired) / Double(requiredItems.count) * 100.0
    }

    var incompleteRequiredItems: [SafetyChecklistItem] {
        return items.filter { $0.isRequired && !$0.isCompleted }
    }

    var incompleteCriticalItems: [SafetyChecklistItem] {
        return items.filter { $0.priority == .critical && !$0.isCompleted }
    }
}

/// Safety violation or concern report
struct SafetyViolationReport: Identifiable, Codable {
    let id: UUID
    let reportDate: Date
    let technicianId: String
    let violationType: SafetyViolationType
    let category: SafetyChecklistCategory
    let description: String
    let severity: SafetyViolationSeverity
    let location: String?
    let latitude: Double?
    let longitude: Double?
    let photos: [Data]
    let correctiveAction: String?
    let reportedToSupervisor: Bool
    let supervisorNotifiedAt: Date?
    let resolved: Bool
    let resolvedAt: Date?
    let followupRequired: Bool

    init(
        id: UUID = UUID(),
        reportDate: Date = Date(),
        technicianId: String,
        violationType: SafetyViolationType,
        category: SafetyChecklistCategory,
        description: String,
        severity: SafetyViolationSeverity,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        photos: [UIImage] = []
    ) {
        self.id = id
        self.reportDate = reportDate
        self.technicianId = technicianId
        self.violationType = violationType
        self.category = category
        self.description = description
        self.severity = severity
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.photos = photos.compactMap { $0.jpegData(compressionQuality: 0.8) }
        self.correctiveAction = nil
        self.reportedToSupervisor = false
        self.supervisorNotifiedAt = nil
        self.resolved = false
        self.resolvedAt = nil
        self.followupRequired = severity == .high || severity == .critical
    }

    // Helper to get photos as UIImages
    var photosAsImages: [UIImage] {
        return photos.compactMap { UIImage(data: $0) }
    }
}

/// Types of safety violations
enum SafetyViolationType: String, CaseIterable, Codable {
    case missingPPE = "missing_ppe"
    case improperChemicalHandling = "improper_chemical"
    case equipmentMalfunction = "equipment_malfunction"
    case unsafeWorkPractice = "unsafe_practice"
    case regulatoryViolation = "regulatory_violation"
    case environmentalConcern = "environmental"
    case customerSafety = "customer_safety"
    case weatherHazard = "weather_hazard"

    var displayName: String {
        switch self {
        case .missingPPE: return "Missing Personal Protective Equipment"
        case .improperChemicalHandling: return "Improper Chemical Handling"
        case .equipmentMalfunction: return "Equipment Malfunction"
        case .unsafeWorkPractice: return "Unsafe Work Practice"
        case .regulatoryViolation: return "Regulatory Violation"
        case .environmentalConcern: return "Environmental Concern"
        case .customerSafety: return "Customer Safety Issue"
        case .weatherHazard: return "Weather Hazard"
        }
    }
}

/// Safety violation severity levels
enum SafetyViolationSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }

    var requiresImmediateAction: Bool {
        return self == .high || self == .critical
    }
}

// MARK: - Model Conversion Extensions
// Note: Core Data entity extensions will be added here as needed