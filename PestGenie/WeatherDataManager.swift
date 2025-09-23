import Foundation
import CoreData
import CoreLocation

/// Manages weather data persistence and caching using Core Data
@MainActor
final class WeatherDataManager: ObservableObject {
    static let shared = WeatherDataManager()

    @Published var currentWeather: WeatherData? = nil

    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "WeatherDataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Failed to load weather data store: \(error)")
            }
        }
        return container
    }()

    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    private init() {
        // Initialize with sample weather data
        currentWeather = WeatherData(
            id: UUID(),
            temperature: 75.0,
            feelsLike: 78.0,
            humidity: 65,
            pressure: 30.12,
            windSpeed: 8.5,
            windDirection: 180.0,
            uvIndex: 6.0,
            precipitationProbability: 15,
            visibility: 10.0,
            cloudCover: 25,
            condition: "Partly Cloudy",
            description: "Partly cloudy with light winds",
            timestamp: Date(),
            location: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        )
    }

    // MARK: - Weather Data Operations

    /// Save weather data to Core Data for offline access
    func saveWeatherData(_ weatherData: WeatherData, for location: CLLocationCoordinate2D) async {
        let entity = WeatherDataEntity(context: context)
        entity.id = weatherData.id
        entity.temperature = weatherData.temperature
        entity.feelsLike = weatherData.feelsLike
        entity.humidity = Int16(weatherData.humidity)
        entity.pressure = weatherData.pressure
        entity.windSpeed = weatherData.windSpeed
        entity.windDirection = weatherData.windDirection
        entity.uvIndex = weatherData.uvIndex
        entity.precipitationProbability = Int16(weatherData.precipitationProbability)
        entity.visibility = weatherData.visibility
        entity.cloudCover = Int16(weatherData.cloudCover)
        entity.condition = weatherData.condition
        entity.conditionDescription = weatherData.description
        entity.timestamp = weatherData.timestamp
        entity.latitude = location.latitude
        entity.longitude = location.longitude
        entity.isSafeForTreatment = weatherData.isSafeForSprayTreatment
        entity.weatherQualityScore = weatherData.weatherQualityScore

        // Determine safety level
        let safetyAnalysis = TreatmentSafetyAnalysis(from: weatherData)
        entity.safetyLevel = safetyAnalysis.overallSafety.rawValue

        await saveContext()

        // Clean up old weather data (keep only last 7 days)
        await cleanupOldWeatherData()
    }

    /// Retrieve cached weather data for a location
    func getCachedWeatherData(for location: CLLocationCoordinate2D, maxAge: TimeInterval = 600) async -> WeatherData? {
        let request = WeatherDataEntity.fetchRequest()
        let cutoffDate = Date().addingTimeInterval(-maxAge)

        // Search within 1km radius
        let latRange = 0.009 // approximately 1km
        let lonRange = 0.009

        request.predicate = NSPredicate(format: """
            timestamp > %@ AND
            latitude BETWEEN {%f, %f} AND
            longitude BETWEEN {%f, %f}
        """,
        cutoffDate as NSDate,
        location.latitude - latRange, location.latitude + latRange,
        location.longitude - lonRange, location.longitude + lonRange
        )

        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 1

        do {
            let entities = try context.fetch(request)
            guard let entity = entities.first else { return nil }

            return convertToWeatherData(entity)
        } catch {
            print("Failed to fetch cached weather data: \(error)")
            return nil
        }
    }

    /// Get weather history for a specific job
    func getWeatherHistory(for jobId: UUID) async -> [WeatherData] {
        let request = WeatherDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "associatedJobID == %@", jobId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        do {
            let entities = try context.fetch(request)
            return entities.compactMap(convertToWeatherData)
        } catch {
            print("Failed to fetch weather history: \(error)")
            return []
        }
    }

    /// Associate weather data with a specific job
    func associateWeatherWithJob(_ weatherData: WeatherData, jobId: UUID) async {
        let request = WeatherDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", weatherData.id as CVarArg)

        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.associatedJobID = jobId
                await saveContext()
            }
        } catch {
            print("Failed to associate weather with job: \(error)")
        }
    }

    // MARK: - Weather Alerts

    /// Save a weather alert
    func saveWeatherAlert(_ alert: WeatherAlert, for location: CLLocationCoordinate2D) async {
        let entity = WeatherAlertEntity(context: context)
        entity.id = UUID()
        entity.alertType = String(describing: alert.type)
        entity.title = alert.title
        entity.message = alert.message
        entity.priority = String(describing: alert.priority)
        entity.timestamp = Date()
        entity.isRead = false
        entity.latitude = location.latitude
        entity.longitude = location.longitude
        entity.expirationDate = Date().addingTimeInterval(3600) // 1 hour expiration

        await saveContext()
    }

    /// Get unread weather alerts
    func getUnreadWeatherAlerts() async -> [WeatherAlertEntity] {
        let request = WeatherAlertEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isRead == false AND (expirationDate == nil OR expirationDate > %@)", Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch weather alerts: \(error)")
            return []
        }
    }

    /// Mark weather alert as read
    func markAlertAsRead(_ alertId: UUID) async {
        let request = WeatherAlertEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", alertId as CVarArg)

        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.isRead = true
                await saveContext()
            }
        } catch {
            print("Failed to mark alert as read: \(error)")
        }
    }

    // MARK: - Weather Forecasts

    /// Save weather forecast data
    func saveWeatherForecast(_ forecasts: [WeatherForecast], for location: CLLocationCoordinate2D) async {
        // Remove old forecasts for this location
        await removeOldForecasts(for: location)

        for forecast in forecasts {
            let entity = WeatherForecastEntity(context: context)
            entity.id = forecast.id
            entity.forecastDate = forecast.date
            entity.temperature = forecast.temperature
            entity.humidity = Int16(forecast.humidity)
            entity.windSpeed = forecast.windSpeed
            entity.precipitationProbability = Int16(forecast.precipitationProbability)
            entity.condition = forecast.condition
            entity.conditionDescription = forecast.description
            entity.createdAt = Date()
            entity.latitude = location.latitude
            entity.longitude = location.longitude
        }

        await saveContext()
    }

    /// Get cached weather forecasts
    func getCachedWeatherForecast(for location: CLLocationCoordinate2D) async -> [WeatherForecast] {
        let request = WeatherForecastEntity.fetchRequest()

        // Search within 1km radius
        let latRange = 0.009
        let lonRange = 0.009
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour old max

        request.predicate = NSPredicate(format: """
            createdAt > %@ AND
            latitude BETWEEN {%f, %f} AND
            longitude BETWEEN {%f, %f}
        """,
        cutoffDate as NSDate,
        location.latitude - latRange, location.latitude + latRange,
        location.longitude - lonRange, location.longitude + lonRange
        )

        request.sortDescriptors = [NSSortDescriptor(key: "forecastDate", ascending: true)]

        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                WeatherForecast(
                    id: entity.id,
                    date: entity.forecastDate,
                    temperature: entity.temperature,
                    humidity: Int(entity.humidity),
                    windSpeed: entity.windSpeed,
                    precipitationProbability: Int(entity.precipitationProbability),
                    condition: entity.condition,
                    description: entity.conditionDescription
                )
            }
        } catch {
            print("Failed to fetch cached forecast: \(error)")
            return []
        }
    }

    // MARK: - Analytics and Reporting

    /// Get weather statistics for a date range
    func getWeatherStatistics(from startDate: Date, to endDate: Date) async -> WeatherStatistics {
        let request = WeatherDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp BETWEEN {%@, %@}", startDate as NSDate, endDate as NSDate)

        do {
            let entities = try context.fetch(request)
            return calculateWeatherStatistics(from: entities)
        } catch {
            print("Failed to fetch weather statistics: \(error)")
            return WeatherStatistics.empty
        }
    }

    /// Get treatment effectiveness correlation with weather
    func getTreatmentWeatherCorrelation() async -> TreatmentWeatherCorrelation {
        let request = WeatherDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "associatedJobID != nil")

        do {
            let entities = try context.fetch(request)
            return analyzeTreatmentCorrelation(from: entities)
        } catch {
            print("Failed to analyze treatment correlation: \(error)")
            return TreatmentWeatherCorrelation.empty
        }
    }

    // MARK: - Data Management

    private func cleanupOldWeatherData() async {
        let request = WeatherDataEntity.fetchRequest()
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 3600) // 7 days
        request.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)

        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            await saveContext()
        } catch {
            print("Failed to cleanup old weather data: \(error)")
        }
    }

    private func removeOldForecasts(for location: CLLocationCoordinate2D) async {
        let request = WeatherForecastEntity.fetchRequest()
        let latRange = 0.009
        let lonRange = 0.009

        request.predicate = NSPredicate(format: """
            latitude BETWEEN {%f, %f} AND
            longitude BETWEEN {%f, %f}
        """,
        location.latitude - latRange, location.latitude + latRange,
        location.longitude - lonRange, location.longitude + lonRange
        )

        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
        } catch {
            print("Failed to remove old forecasts: \(error)")
        }
    }

    private func saveContext() async {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Failed to save weather data context: \(error)")
        }
    }

    // MARK: - Data Conversion

    private func convertToWeatherData(_ entity: WeatherDataEntity) -> WeatherData {
        return WeatherData(
            id: entity.id,
            temperature: entity.temperature,
            feelsLike: entity.feelsLike,
            humidity: Int(entity.humidity),
            pressure: entity.pressure,
            windSpeed: entity.windSpeed,
            windDirection: entity.windDirection,
            uvIndex: entity.uvIndex,
            precipitationProbability: Int(entity.precipitationProbability),
            visibility: entity.visibility,
            cloudCover: Int(entity.cloudCover),
            condition: entity.condition,
            description: entity.conditionDescription,
            timestamp: entity.timestamp,
            location: CLLocationCoordinate2D(
                latitude: entity.latitude,
                longitude: entity.longitude
            )
        )
    }

    // MARK: - Analytics

    private func calculateWeatherStatistics(from entities: [WeatherDataEntity]) -> WeatherStatistics {
        guard !entities.isEmpty else { return WeatherStatistics.empty }

        let temperatures = entities.map { $0.temperature }
        let windSpeeds = entities.map { $0.windSpeed }
        let humidities = entities.map { Double($0.humidity) }

        let safeForTreatmentCount = entities.filter { $0.isSafeForTreatment }.count
        let treatmentSafetyPercentage = Double(safeForTreatmentCount) / Double(entities.count) * 100

        return WeatherStatistics(
            totalReadings: entities.count,
            averageTemperature: temperatures.reduce(0, +) / Double(temperatures.count),
            minTemperature: temperatures.min() ?? 0,
            maxTemperature: temperatures.max() ?? 0,
            averageWindSpeed: windSpeeds.reduce(0, +) / Double(windSpeeds.count),
            maxWindSpeed: windSpeeds.max() ?? 0,
            averageHumidity: humidities.reduce(0, +) / Double(humidities.count),
            treatmentSafetyPercentage: treatmentSafetyPercentage,
            mostCommonCondition: findMostCommonCondition(from: entities)
        )
    }

    private func findMostCommonCondition(from entities: [WeatherDataEntity]) -> String {
        let conditions = entities.map { $0.condition }
        let conditionCounts = conditions.reduce(into: [:]) { counts, condition in
            counts[condition, default: 0] += 1
        }
        return conditionCounts.max(by: { $0.value < $1.value })?.key ?? "Unknown"
    }

    private func analyzeTreatmentCorrelation(from entities: [WeatherDataEntity]) -> TreatmentWeatherCorrelation {
        let safeTreatments = entities.filter { $0.isSafeForTreatment }
        let unsafeTreatments = entities.filter { !$0.isSafeForTreatment }

        return TreatmentWeatherCorrelation(
            totalTreatments: entities.count,
            safeTreatments: safeTreatments.count,
            unsafeTreatments: unsafeTreatments.count,
            averageSafeWindSpeed: safeTreatments.map { $0.windSpeed }.reduce(0, +) / Double(max(1, safeTreatments.count)),
            averageUnsafeWindSpeed: unsafeTreatments.map { $0.windSpeed }.reduce(0, +) / Double(max(1, unsafeTreatments.count)),
            optimalConditionsPercentage: Double(safeTreatments.count) / Double(entities.count) * 100
        )
    }
}

// MARK: - Supporting Types

struct WeatherStatistics {
    let totalReadings: Int
    let averageTemperature: Double
    let minTemperature: Double
    let maxTemperature: Double
    let averageWindSpeed: Double
    let maxWindSpeed: Double
    let averageHumidity: Double
    let treatmentSafetyPercentage: Double
    let mostCommonCondition: String

    static let empty = WeatherStatistics(
        totalReadings: 0,
        averageTemperature: 0,
        minTemperature: 0,
        maxTemperature: 0,
        averageWindSpeed: 0,
        maxWindSpeed: 0,
        averageHumidity: 0,
        treatmentSafetyPercentage: 0,
        mostCommonCondition: "Unknown"
    )
}

struct TreatmentWeatherCorrelation {
    let totalTreatments: Int
    let safeTreatments: Int
    let unsafeTreatments: Int
    let averageSafeWindSpeed: Double
    let averageUnsafeWindSpeed: Double
    let optimalConditionsPercentage: Double

    static let empty = TreatmentWeatherCorrelation(
        totalTreatments: 0,
        safeTreatments: 0,
        unsafeTreatments: 0,
        averageSafeWindSpeed: 0,
        averageUnsafeWindSpeed: 0,
        optimalConditionsPercentage: 0
    )
}