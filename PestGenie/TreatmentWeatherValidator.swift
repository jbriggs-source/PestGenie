import Foundation
import CoreLocation

/// Validates chemical treatment conditions against weather data and EPA regulations
@MainActor
final class TreatmentWeatherValidator: ObservableObject {
    static let shared = TreatmentWeatherValidator()

    @Published var currentValidation: TreatmentValidation?
    @Published var validationHistory: [TreatmentValidation] = []
    @Published var isValidating = false

    private let weatherAPI = WeatherAPI.shared
    private let weatherDataManager = WeatherDataManager.shared

    private init() {}

    // MARK: - Treatment Validation

    func validateTreatment(
        chemical: Chemical,
        applicationMethod: ApplicationMethod,
        targetArea: Double,
        location: CLLocationCoordinate2D,
        scheduledTime: Date = Date()
    ) async -> TreatmentValidation {
        isValidating = true

        do {
            // Get current and forecast weather
            let currentWeather = try await weatherAPI.fetchCurrentWeather(for: location)
            let forecast = try await weatherAPI.fetchWeatherForecast(for: location)

            // Perform comprehensive validation
            let validation = performValidation(
                chemical: chemical,
                applicationMethod: applicationMethod,
                targetArea: targetArea,
                location: location,
                scheduledTime: scheduledTime,
                currentWeather: currentWeather,
                forecast: forecast
            )

            currentValidation = validation
            validationHistory.append(validation)

            // Save validation to Core Data for record keeping
            await saveValidationRecord(validation)

            isValidating = false
            return validation

        } catch {
            let errorValidation = TreatmentValidation(
                id: UUID(),
                chemicalId: chemical.id,
                applicationMethod: applicationMethod,
                targetArea: targetArea,
                location: location,
                scheduledTime: scheduledTime,
                validationTime: Date(),
                canProceed: false,
                overallRisk: .high,
                weatherConditions: nil,
                validationResults: [],
                epaCompliance: EPAComplianceResult(
                    isCompliant: false,
                    violations: ["Unable to validate weather conditions"],
                    recommendations: ["Retry validation before proceeding"]
                ),
                recommendations: ["Check weather data and try again"],
                expirationTime: Date().addingTimeInterval(3600)
            )

            currentValidation = errorValidation
            isValidating = false
            return errorValidation
        }
    }

    private func performValidation(
        chemical: Chemical,
        applicationMethod: ApplicationMethod,
        targetArea: Double,
        location: CLLocationCoordinate2D,
        scheduledTime: Date,
        currentWeather: WeatherData,
        forecast: [WeatherForecast]
    ) -> TreatmentValidation {
        var validationResults: [ValidationResult] = []
        var recommendations: [String] = []
        var canProceed = true
        var overallRisk = RiskLevel.low

        // Wind Speed Validation
        let windValidation = validateWindConditions(
            weather: currentWeather,
            applicationMethod: applicationMethod,
            chemical: chemical
        )
        validationResults.append(windValidation)
        if windValidation.severity == .critical { canProceed = false }
        if windValidation.riskLevel.rawValue > overallRisk.rawValue { overallRisk = windValidation.riskLevel }

        // Temperature Validation
        let temperatureValidation = validateTemperatureConditions(
            weather: currentWeather,
            chemical: chemical,
            applicationMethod: applicationMethod
        )
        validationResults.append(temperatureValidation)
        if temperatureValidation.severity == .critical { canProceed = false }
        if temperatureValidation.riskLevel.rawValue > overallRisk.rawValue { overallRisk = temperatureValidation.riskLevel }

        // Humidity Validation
        let humidityValidation = validateHumidityConditions(
            weather: currentWeather,
            applicationMethod: applicationMethod
        )
        validationResults.append(humidityValidation)
        if humidityValidation.riskLevel.rawValue > overallRisk.rawValue { overallRisk = humidityValidation.riskLevel }

        // Precipitation Validation
        let precipitationValidation = validatePrecipitationConditions(
            weather: currentWeather,
            forecast: forecast,
            applicationMethod: applicationMethod,
            chemical: chemical
        )
        validationResults.append(precipitationValidation)
        if precipitationValidation.severity == .critical { canProceed = false }
        if precipitationValidation.riskLevel.rawValue > overallRisk.rawValue { overallRisk = precipitationValidation.riskLevel }

        // UV Index and Heat Validation
        let uvValidation = validateUVConditions(weather: currentWeather, chemical: chemical)
        validationResults.append(uvValidation)
        if uvValidation.riskLevel.rawValue > overallRisk.rawValue { overallRisk = uvValidation.riskLevel }

        // Time-based Validation
        let timeValidation = validateTimingConditions(
            scheduledTime: scheduledTime,
            weather: currentWeather,
            chemical: chemical
        )
        validationResults.append(timeValidation)
        if timeValidation.riskLevel.rawValue > overallRisk.rawValue { overallRisk = timeValidation.riskLevel }

        // EPA Compliance Check
        let epaCompliance = validateEPACompliance(
            chemical: chemical,
            applicationMethod: applicationMethod,
            weather: currentWeather,
            targetArea: targetArea
        )

        // Generate recommendations
        recommendations = generateRecommendations(
            validationResults: validationResults,
            chemical: chemical,
            applicationMethod: applicationMethod,
            weather: currentWeather
        )

        return TreatmentValidation(
            id: UUID(),
            chemicalId: chemical.id,
            applicationMethod: applicationMethod,
            targetArea: targetArea,
            location: location,
            scheduledTime: scheduledTime,
            validationTime: Date(),
            canProceed: canProceed && epaCompliance.isCompliant,
            overallRisk: overallRisk,
            weatherConditions: currentWeather,
            validationResults: validationResults,
            epaCompliance: epaCompliance,
            recommendations: recommendations,
            expirationTime: Date().addingTimeInterval(1800) // 30 minutes
        )
    }

    // MARK: - Individual Validation Methods

    private func validateWindConditions(
        weather: WeatherData,
        applicationMethod: ApplicationMethod,
        chemical: Chemical
    ) -> ValidationResult {
        let windSpeed = weather.windSpeed
        var severity = ValidationSeverity.info
        var riskLevel = RiskLevel.low
        var message = "Wind conditions are acceptable"
        var passed = true

        switch applicationMethod {
        case .spray, .aerosol:
            if windSpeed > 15 {
                severity = .critical
                riskLevel = .high
                message = "Wind speed too high for spray applications (\(Int(windSpeed)) mph)"
                passed = false
            } else if windSpeed > 10 {
                severity = .warning
                riskLevel = .medium
                message = "Elevated wind speed - use drift reduction measures (\(Int(windSpeed)) mph)"
            } else if windSpeed < 2 {
                severity = .warning
                riskLevel = .medium
                message = "Very low wind may cause droplet settling (\(Int(windSpeed)) mph)"
            }

        case .dust, .granular:
            if windSpeed > 20 {
                severity = .critical
                riskLevel = .high
                message = "Wind speed too high for granular applications (\(Int(windSpeed)) mph)"
                passed = false
            } else if windSpeed > 15 {
                severity = .warning
                riskLevel = .medium
                message = "High wind speed - monitor drift (\(Int(windSpeed)) mph)"
            }

        case .fogger:
            if windSpeed > 8 {
                severity = .critical
                riskLevel = .high
                message = "Wind speed too high for fogging (\(Int(windSpeed)) mph)"
                passed = false
            }

        default:
            // Other methods are less affected by wind
            if windSpeed > 25 {
                severity = .warning
                riskLevel = .medium
                message = "Extreme wind conditions - exercise caution"
            }
        }

        return ValidationResult(
            category: .windConditions,
            passed: passed,
            severity: severity,
            riskLevel: riskLevel,
            message: message,
            value: windSpeed,
            threshold: getWindThreshold(for: applicationMethod),
            recommendations: getWindRecommendations(windSpeed: windSpeed, method: applicationMethod)
        )
    }

    private func validateTemperatureConditions(
        weather: WeatherData,
        chemical: Chemical,
        applicationMethod: ApplicationMethod
    ) -> ValidationResult {
        let temperature = weather.temperature
        var severity = ValidationSeverity.info
        var riskLevel = RiskLevel.low
        var message = "Temperature conditions are suitable"
        var passed = true

        // Check chemical-specific temperature requirements
        if temperature > 85 {
            severity = .warning
            riskLevel = .medium
            message = "High temperature may reduce treatment effectiveness (\(Int(temperature))°F)"

            if temperature > 95 {
                severity = .critical
                riskLevel = .high
                message = "Extreme heat - treatment not recommended (\(Int(temperature))°F)"
                passed = false
            }
        } else if temperature < 50 {
            severity = .warning
            riskLevel = .medium
            message = "Low temperature may reduce chemical activity (\(Int(temperature))°F)"

            if temperature < 35 {
                severity = .critical
                riskLevel = .high
                message = "Temperature too low for effective treatment (\(Int(temperature))°F)"
                passed = false
            }
        }

        // Additional checks for specific chemical types
        if chemical.activeIngredient.lowercased().contains("pyrethroid") && temperature > 80 {
            severity = .warning
            riskLevel = .medium
            message = "High temperature reduces pyrethroid effectiveness"
        }

        return ValidationResult(
            category: .temperatureConditions,
            passed: passed,
            severity: severity,
            riskLevel: riskLevel,
            message: message,
            value: temperature,
            threshold: 85,
            recommendations: getTemperatureRecommendations(temperature: temperature, chemical: chemical)
        )
    }

    private func validateHumidityConditions(
        weather: WeatherData,
        applicationMethod: ApplicationMethod
    ) -> ValidationResult {
        let humidity = Double(weather.humidity)
        var severity = ValidationSeverity.info
        var riskLevel = RiskLevel.low
        var message = "Humidity levels are acceptable"
        let passed = true

        if humidity > 85 {
            severity = .warning
            riskLevel = .medium
            message = "High humidity may affect drying time (\(weather.humidity)%)"
        } else if humidity < 30 && (applicationMethod == .spray || applicationMethod == .aerosol) {
            severity = .warning
            riskLevel = .medium
            message = "Low humidity may cause rapid evaporation (\(weather.humidity)%)"
        }

        return ValidationResult(
            category: .humidityConditions,
            passed: passed,
            severity: severity,
            riskLevel: riskLevel,
            message: message,
            value: humidity,
            threshold: 85,
            recommendations: getHumidityRecommendations(humidity: humidity, method: applicationMethod)
        )
    }

    private func validatePrecipitationConditions(
        weather: WeatherData,
        forecast: [WeatherForecast],
        applicationMethod: ApplicationMethod,
        chemical: Chemical
    ) -> ValidationResult {
        let precipitationProbability = weather.precipitationProbability
        var severity = ValidationSeverity.info
        var riskLevel = RiskLevel.low
        var message = "Precipitation risk is acceptable"
        var passed = true

        // Check current conditions
        if precipitationProbability > 50 {
            severity = .critical
            riskLevel = .high
            message = "High precipitation risk - treatment not recommended (\(precipitationProbability)%)"
            passed = false
        } else if precipitationProbability > 30 {
            severity = .warning
            riskLevel = .medium
            message = "Moderate precipitation risk - monitor conditions (\(precipitationProbability)%)"
        }

        // Check forecast for next few hours
        let nearTermForecast = forecast.prefix(3) // Next 9 hours (3-hour intervals)
        let maxForecastPrecip = nearTermForecast.map { $0.precipitationProbability }.max() ?? 0

        if maxForecastPrecip > 70 {
            severity = .warning
            riskLevel = .medium
            message = "Rain expected within next few hours - consider timing"
        }

        return ValidationResult(
            category: .precipitationRisk,
            passed: passed,
            severity: severity,
            riskLevel: riskLevel,
            message: message,
            value: Double(precipitationProbability),
            threshold: 30,
            recommendations: getPrecipitationRecommendations(
                probability: precipitationProbability,
                method: applicationMethod,
                chemical: chemical
            )
        )
    }

    private func validateUVConditions(weather: WeatherData, chemical: Chemical) -> ValidationResult {
        let uvIndex = weather.uvIndex
        var severity = ValidationSeverity.info
        var riskLevel = RiskLevel.low
        var message = "UV conditions are safe"
        let passed = true

        if uvIndex > 8 {
            severity = .warning
            riskLevel = .medium
            message = "High UV index - ensure technician protection (UV: \(Int(uvIndex)))"
        } else if uvIndex > 6 {
            severity = .info
            riskLevel = .low
            message = "Moderate UV index - use sun protection (UV: \(Int(uvIndex)))"
        }

        // Check for UV-sensitive chemicals
        if chemical.storageRequirements.lowercased().contains("light") && uvIndex > 6 {
            severity = .warning
            riskLevel = .medium
            message = "UV-sensitive chemical - avoid direct sunlight exposure"
        }

        return ValidationResult(
            category: .uvExposure,
            passed: passed,
            severity: severity,
            riskLevel: riskLevel,
            message: message,
            value: uvIndex,
            threshold: 8,
            recommendations: getUVRecommendations(uvIndex: uvIndex, chemical: chemical)
        )
    }

    private func validateTimingConditions(
        scheduledTime: Date,
        weather: WeatherData,
        chemical: Chemical
    ) -> ValidationResult {
        let hour = Calendar.current.component(.hour, from: scheduledTime)
        var severity = ValidationSeverity.info
        var riskLevel = RiskLevel.low
        var message = "Treatment timing is appropriate"
        let passed = true

        // Check for optimal application times
        if hour >= 10 && hour <= 14 && weather.temperature > 80 {
            severity = .warning
            riskLevel = .medium
            message = "Midday application during hot weather - consider earlier/later timing"
        }

        // Check for wind patterns
        if hour >= 6 && hour <= 10 {
            message = "Good timing - typically calmer morning conditions"
        } else if hour >= 18 && hour <= 20 {
            message = "Good timing - typically calmer evening conditions"
        }

        // Check chemical-specific timing requirements
        if chemical.reentryInterval > 0 && hour > 16 {
            severity = .info
            riskLevel = .low
            message = "Late application - consider reentry interval timing"
        }

        return ValidationResult(
            category: .applicationTiming,
            passed: passed,
            severity: severity,
            riskLevel: riskLevel,
            message: message,
            value: Double(hour),
            threshold: 14,
            recommendations: getTimingRecommendations(hour: hour, weather: weather, chemical: chemical)
        )
    }

    private func validateEPACompliance(
        chemical: Chemical,
        applicationMethod: ApplicationMethod,
        weather: WeatherData,
        targetArea: Double
    ) -> EPAComplianceResult {
        var violations: [String] = []
        var recommendations: [String] = []

        // Wind speed requirements
        if weather.windSpeed > 15 && (applicationMethod == .spray || applicationMethod == .aerosol) {
            violations.append("Wind speed exceeds EPA guidelines for spray applications")
        }

        // Temperature restrictions
        if weather.temperature > 90 {
            recommendations.append("Consider temperature effects on chemical stability")
        }

        // Buffer zone calculations
        let requiredBuffer = calculateBufferZone(chemical: chemical, applicationMethod: applicationMethod, windSpeed: weather.windSpeed)
        recommendations.append("Maintain \(Int(requiredBuffer))-foot buffer from sensitive areas")

        // Reentry interval considerations
        if chemical.reentryInterval > 0 {
            recommendations.append("Ensure \(chemical.reentryInterval)-hour reentry interval is observed")
        }

        // Signal word requirements
        switch chemical.signalWord {
        case .danger:
            recommendations.append("DANGER product - use maximum PPE and precautions")
        case .warning:
            recommendations.append("WARNING product - use appropriate safety measures")
        case .caution:
            recommendations.append("CAUTION product - follow standard safety protocols")
        }

        return EPAComplianceResult(
            isCompliant: violations.isEmpty,
            violations: violations,
            recommendations: recommendations
        )
    }

    // MARK: - Helper Methods

    private func getWindThreshold(for method: ApplicationMethod) -> Double {
        switch method {
        case .spray, .aerosol: return 15
        case .fogger: return 8
        case .dust, .granular: return 20
        default: return 25
        }
    }

    private func calculateBufferZone(chemical: Chemical, applicationMethod: ApplicationMethod, windSpeed: Double) -> Double {
        var baseBuffer: Double = 25 // Base buffer in feet

        // Adjust for application method
        switch applicationMethod {
        case .spray, .aerosol:
            baseBuffer = 50
        case .fogger:
            baseBuffer = 100
        case .granular:
            baseBuffer = 25
        default:
            baseBuffer = 25
        }

        // Adjust for wind speed
        let windMultiplier = min(windSpeed / 5.0, 3.0) // Cap at 3x
        baseBuffer *= windMultiplier

        // Adjust for chemical toxicity
        switch chemical.signalWord {
        case .danger:
            baseBuffer *= 2.0
        case .warning:
            baseBuffer *= 1.5
        case .caution:
            baseBuffer *= 1.0
        }

        return baseBuffer
    }

    private func generateRecommendations(
        validationResults: [ValidationResult],
        chemical: Chemical,
        applicationMethod: ApplicationMethod,
        weather: WeatherData
    ) -> [String] {
        var recommendations: [String] = []

        // Collect recommendations from validation results
        for result in validationResults {
            recommendations.append(contentsOf: result.recommendations)
        }

        // Add method-specific recommendations
        switch applicationMethod {
        case .spray, .aerosol:
            recommendations.append("Use drift-reducing nozzles")
            recommendations.append("Apply at low pressure to minimize drift")
        case .granular:
            recommendations.append("Water in granules if rain not expected within 24 hours")
        case .bait:
            recommendations.append("Place baits in protected areas away from moisture")
        default:
            break
        }

        // Add chemical-specific recommendations
        if chemical.signalWord == .danger {
            recommendations.append("Use maximum personal protective equipment")
        }

        if chemical.pphiDays > 0 {
            recommendations.append("Observe \(chemical.pphiDays)-day pre-harvest interval")
        }

        return Array(Set(recommendations)) // Remove duplicates
    }

    // MARK: - Recommendation Generators

    private func getWindRecommendations(windSpeed: Double, method: ApplicationMethod) -> [String] {
        var recommendations: [String] = []

        if windSpeed > 10 {
            recommendations.append("Use drift-reducing nozzles")
            recommendations.append("Reduce spray pressure")
            recommendations.append("Increase buffer zones")
        }

        if windSpeed < 3 {
            recommendations.append("Be aware of temperature inversions")
            recommendations.append("Monitor for droplet settling")
        }

        return recommendations
    }

    private func getTemperatureRecommendations(temperature: Double, chemical: Chemical) -> [String] {
        var recommendations: [String] = []

        if temperature > 80 {
            recommendations.append("Apply during cooler parts of day")
            recommendations.append("Monitor chemical stability")
            recommendations.append("Ensure adequate technician hydration")
        }

        if temperature < 50 {
            recommendations.append("Wait for warmer conditions if possible")
            recommendations.append("Allow extra time for chemical activation")
        }

        return recommendations
    }

    private func getHumidityRecommendations(humidity: Double, method: ApplicationMethod) -> [String] {
        var recommendations: [String] = []

        if humidity > 80 {
            recommendations.append("Allow extra drying time")
            recommendations.append("Monitor for extended persistence")
        }

        if humidity < 40 && method == .spray {
            recommendations.append("Use larger droplet size to prevent evaporation")
            recommendations.append("Apply during higher humidity periods")
        }

        return recommendations
    }

    private func getPrecipitationRecommendations(probability: Int, method: ApplicationMethod, chemical: Chemical) -> [String] {
        var recommendations: [String] = []

        if probability > 30 {
            recommendations.append("Monitor radar and postpone if rain imminent")
            recommendations.append("Have equipment ready for quick cleanup")
        }

        if method == .granular && probability > 20 {
            recommendations.append("Rain may help activate granular products")
        }

        return recommendations
    }

    private func getUVRecommendations(uvIndex: Double, chemical: Chemical) -> [String] {
        var recommendations: [String] = []

        if uvIndex > 6 {
            recommendations.append("Ensure technician uses sun protection")
            recommendations.append("Take frequent breaks in shade")
        }

        if uvIndex > 8 {
            recommendations.append("Consider applying during lower UV periods")
        }

        return recommendations
    }

    private func getTimingRecommendations(hour: Int, weather: WeatherData, chemical: Chemical) -> [String] {
        var recommendations: [String] = []

        if hour >= 10 && hour <= 14 && weather.temperature > 80 {
            recommendations.append("Consider early morning or evening application")
        }

        if chemical.reentryInterval > 0 {
            recommendations.append("Plan timing to minimize disruption during reentry interval")
        }

        return recommendations
    }

    // MARK: - Data Persistence

    private func saveValidationRecord(_ validation: TreatmentValidation) async {
        // Save validation record to Core Data for compliance tracking
        // This would integrate with the existing data management system
        print("Saving validation record: \(validation.id)")
    }
}

// MARK: - Supporting Types

struct TreatmentValidation: Identifiable, Codable {
    let id: UUID
    let chemicalId: UUID
    let applicationMethod: ApplicationMethod
    let targetArea: Double
    let location: CLLocationCoordinate2D
    let scheduledTime: Date
    let validationTime: Date
    let canProceed: Bool
    let overallRisk: RiskLevel
    let weatherConditions: WeatherData?
    let validationResults: [ValidationResult]
    let epaCompliance: EPAComplianceResult
    let recommendations: [String]
    let expirationTime: Date

    var isExpired: Bool {
        Date() > expirationTime
    }

    var validationSummary: String {
        if canProceed {
            return "Treatment approved with \(overallRisk.rawValue) risk level"
        } else {
            return "Treatment not recommended - conditions unsafe"
        }
    }
}

struct ValidationResult: Codable {
    let category: ValidationCategory
    let passed: Bool
    let severity: ValidationSeverity
    let riskLevel: RiskLevel
    let message: String
    let value: Double
    let threshold: Double
    let recommendations: [String]
}

struct EPAComplianceResult: Codable {
    let isCompliant: Bool
    let violations: [String]
    let recommendations: [String]
}

enum ValidationCategory: String, Codable, CaseIterable {
    case windConditions = "Wind Conditions"
    case temperatureConditions = "Temperature Conditions"
    case humidityConditions = "Humidity Conditions"
    case precipitationRisk = "Precipitation Risk"
    case uvExposure = "UV Exposure"
    case applicationTiming = "Application Timing"
}

enum ValidationSeverity: String, Codable, CaseIterable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
}

enum RiskLevel: String, Codable, CaseIterable, Comparable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        let order: [RiskLevel] = [.low, .medium, .high]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}