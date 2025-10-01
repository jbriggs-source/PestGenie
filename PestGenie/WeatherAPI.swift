import Foundation
import CoreLocation
import Combine

// MARK: - CLLocationCoordinate2D Codable Extension

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

/// Weather API service for fetching real-time weather data and forecasts
/// Integrates with existing NetworkMonitor for connection management
@MainActor
final class WeatherAPI: ObservableObject {
    static let shared = WeatherAPI()

    @Published var currentWeather: WeatherData?
    @Published var forecast: [WeatherForecast] = []
    @Published var isLoading = false
    @Published var lastError: WeatherAPIError?

    private let apiKey = "YOUR_WEATHER_API_KEY" // Configure in production
    private let baseURL = "https://api.openweathermap.org/data/3.0"
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()

    // Cache for recent weather data
    private var weatherCache: [String: CachedWeatherData] = [:]
    private let cacheExpirationTime: TimeInterval = 600 // 10 minutes

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.networkServiceType = .responsiveData
        self.session = URLSession(configuration: config)

        setupNetworkMonitoring()
    }

    // MARK: - Network Monitoring Integration

    private func setupNetworkMonitoring() {
        NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.lastError = .networkUnavailable
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Current Weather

    func fetchCurrentWeather(for location: CLLocationCoordinate2D) async throws -> WeatherData {
        let cacheKey = "\(location.latitude),\(location.longitude)"

        // Check cache first
        if let cached = weatherCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationTime {
            self.currentWeather = cached.data
            return cached.data
        }

        guard NetworkMonitor.shared.isConnected else {
            throw WeatherAPIError.networkUnavailable
        }

        isLoading = true
        lastError = nil

        do {
            let url = buildCurrentWeatherURL(for: location)
            let (data, _) = try await session.data(from: url)

            let response = try JSONDecoder().decode(OpenWeatherMapOneCallResponse.self, from: data)
            let weatherData = convertToWeatherData(response)

            // Cache the result
            weatherCache[cacheKey] = CachedWeatherData(data: weatherData, timestamp: Date())

            // Store in Core Data for offline access
            await WeatherDataManager.shared.saveWeatherData(weatherData, for: location)

            self.currentWeather = weatherData
            isLoading = false

            // Track API usage for performance monitoring
            await PerformanceManager.shared.trackWeatherAPICall(
                success: true,
                dataUsage: data.count,
                responseTime: 0 // Would track actual response time in production
            )

            return weatherData

        } catch {
            isLoading = false
            let weatherError = mapError(error)
            lastError = weatherError

            await PerformanceManager.shared.trackWeatherAPICall(
                success: false,
                dataUsage: 0,
                responseTime: 0
            )

            // Try to return cached data as fallback
            if let cached = weatherCache[cacheKey] {
                return cached.data
            }

            throw weatherError
        }
    }

    // MARK: - Weather Forecast

    func fetchWeatherForecast(for location: CLLocationCoordinate2D, days: Int = 5) async throws -> [WeatherForecast] {
        guard NetworkMonitor.shared.isConnected else {
            throw WeatherAPIError.networkUnavailable
        }

        isLoading = true
        lastError = nil

        do {
            let url = buildForecastURL(for: location, days: days)
            let (data, _) = try await session.data(from: url)

            let response = try JSONDecoder().decode(OpenWeatherMapOneCallResponse.self, from: data)
            let forecasts = convertToWeatherForecasts(response)

            self.forecast = forecasts
            isLoading = false

            return forecasts

        } catch {
            isLoading = false
            let weatherError = mapError(error)
            lastError = weatherError
            throw weatherError
        }
    }

    // MARK: - Weather Alerts and Safety Checks

    func checkTreatmentSafety(for weather: WeatherData) -> TreatmentSafetyResult {
        var warnings: [SafetyWarning] = []
        var canTreat = true

        // Wind speed check
        if weather.windSpeed > 10 { // mph
            warnings.append(.highWind(speed: weather.windSpeed))
            if weather.windSpeed > 15 {
                canTreat = false
            }
        }

        // Temperature checks
        if weather.temperature > 85 { // Fahrenheit
            warnings.append(.highTemperature(temp: weather.temperature))
        }

        if weather.temperature < 50 {
            warnings.append(.lowTemperature(temp: weather.temperature))
            canTreat = false
        }

        // Humidity check
        if weather.humidity > 85 {
            warnings.append(.highHumidity(humidity: weather.humidity))
        }

        // Precipitation check
        if weather.precipitationProbability > 50 {
            warnings.append(.precipitationRisk(probability: weather.precipitationProbability))
            canTreat = false
        }

        // UV index for technician safety
        if weather.uvIndex > 8 {
            warnings.append(.highUVIndex(index: weather.uvIndex))
        }

        return TreatmentSafetyResult(
            canTreat: canTreat,
            warnings: warnings,
            recommendedActions: generateRecommendations(for: warnings)
        )
    }

    func shouldSendWeatherAlert(for weather: WeatherData) -> WeatherAlert? {
        // Critical weather conditions that require immediate alerts
        if weather.windSpeed > 20 {
            return WeatherAlert(
                type: .criticalWind,
                title: "Dangerous Wind Conditions",
                message: "Wind speed: \(Int(weather.windSpeed)) mph. Stop all spray treatments immediately.",
                priority: .critical
            )
        }

        if weather.precipitationProbability > 80 {
            return WeatherAlert(
                type: .severeWeather,
                title: "Heavy Rain Expected",
                message: "High chance of precipitation. Consider postponing outdoor treatments.",
                priority: .high
            )
        }

        if weather.temperature > 95 {
            return WeatherAlert(
                type: .extremeHeat,
                title: "Extreme Heat Warning",
                message: "Temperature: \(Int(weather.temperature))°F. Take frequent breaks and stay hydrated.",
                priority: .high
            )
        }

        return nil
    }

    // MARK: - URL Building

    private func buildCurrentWeatherURL(for location: CLLocationCoordinate2D) -> URL {
        var components = URLComponents(string: "\(baseURL)/onecall")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "imperial"), // Fahrenheit
            URLQueryItem(name: "exclude", value: "minutely,hourly,alerts")
        ]
        return components.url!
    }

    private func buildForecastURL(for location: CLLocationCoordinate2D, days: Int) -> URL {
        var components = URLComponents(string: "\(baseURL)/onecall")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "imperial"),
            URLQueryItem(name: "exclude", value: "current,minutely,alerts") // Get daily forecast
        ]
        return components.url!
    }

    // MARK: - Data Conversion

    private func convertToWeatherData(_ response: OpenWeatherMapOneCallResponse) -> WeatherData {
        return WeatherData(
            id: UUID(),
            temperature: response.current.temp,
            feelsLike: response.current.feels_like,
            humidity: response.current.humidity,
            pressure: Double(response.current.pressure),
            windSpeed: response.current.wind_speed,
            windDirection: Double(response.current.wind_deg),
            uvIndex: response.current.uvi,
            precipitationProbability: Int((response.current.rain?.oneHour ?? 0.0) * 100),
            visibility: Double(response.current.visibility),
            cloudCover: response.current.clouds,
            condition: response.current.weather.first?.main ?? "Unknown",
            description: response.current.weather.first?.description ?? "",
            timestamp: Date(timeIntervalSince1970: TimeInterval(response.current.dt)),
            location: CLLocationCoordinate2D(
                latitude: response.lat,
                longitude: response.lon
            )
        )
    }

    private func convertToWeatherForecasts(_ response: OpenWeatherMapOneCallResponse) -> [WeatherForecast] {
        return response.daily.prefix(5).map { item in
            WeatherForecast(
                id: UUID(),
                date: Date(timeIntervalSince1970: TimeInterval(item.dt)),
                temperature: item.temp.day,
                humidity: item.humidity,
                windSpeed: item.wind_speed,
                precipitationProbability: Int(item.pop * 100),
                condition: item.weather.first?.main ?? "Unknown",
                description: item.weather.first?.description ?? ""
            )
        }
    }

    // MARK: - Error Handling

    private func mapError(_ error: Error) -> WeatherAPIError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .timeout
            default:
                return .requestFailed(urlError.localizedDescription)
            }
        }

        if error is DecodingError {
            return .invalidResponse
        }

        return .unknown(error.localizedDescription)
    }

    // MARK: - Recommendations

    private func generateRecommendations(for warnings: [SafetyWarning]) -> [String] {
        var recommendations: [String] = []

        for warning in warnings {
            switch warning {
            case .highWind:
                recommendations.append("Use drift-reducing nozzles and lower spray pressure")
            case .highTemperature:
                recommendations.append("Schedule treatments for early morning or evening")
            case .lowTemperature:
                recommendations.append("Wait for warmer conditions for optimal effectiveness")
            case .highHumidity:
                recommendations.append("Allow extra drying time between applications")
            case .precipitationRisk:
                recommendations.append("Postpone treatment until dry conditions return")
            case .highUVIndex:
                recommendations.append("Use sun protection and take frequent breaks")
            }
        }

        return recommendations
    }
}

// MARK: - Supporting Types

struct CachedWeatherData {
    let data: WeatherData
    let timestamp: Date
}

struct WeatherData: Identifiable, Codable {
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

    // Computed properties for safety checks
    var isSafeForSprayTreatment: Bool {
        return windSpeed <= 15 &&
               temperature >= 50 &&
               temperature <= 85 &&
               precipitationProbability < 50
    }

    var weatherQualityScore: Double {
        var score = 1.0

        // Wind penalty
        if windSpeed > 10 { score -= 0.3 }
        if windSpeed > 15 { score -= 0.5 }

        // Temperature penalty
        if temperature > 85 || temperature < 50 { score -= 0.4 }

        // Precipitation penalty
        if precipitationProbability > 30 { score -= 0.3 }

        return max(0, score)
    }
}

struct WeatherForecast: Identifiable, Codable {
    let id: UUID
    let date: Date
    let temperature: Double
    let humidity: Int
    let windSpeed: Double
    let precipitationProbability: Int
    let condition: String
    let description: String
}

struct TreatmentSafetyResult {
    let canTreat: Bool
    let warnings: [SafetyWarning]
    let recommendedActions: [String]
}

enum SafetyWarning {
    case highWind(speed: Double)
    case highTemperature(temp: Double)
    case lowTemperature(temp: Double)
    case highHumidity(humidity: Int)
    case precipitationRisk(probability: Int)
    case highUVIndex(index: Double)

    var title: String {
        switch self {
        case .highWind: return "High Wind Speed"
        case .highTemperature: return "High Temperature"
        case .lowTemperature: return "Low Temperature"
        case .highHumidity: return "High Humidity"
        case .precipitationRisk: return "Precipitation Risk"
        case .highUVIndex: return "High UV Index"
        }
    }

    var description: String {
        switch self {
        case .highWind(let speed):
            return "Wind speed: \(Int(speed)) mph"
        case .highTemperature(let temp):
            return "Temperature: \(Int(temp))°F"
        case .lowTemperature(let temp):
            return "Temperature: \(Int(temp))°F"
        case .highHumidity(let humidity):
            return "Humidity: \(humidity)%"
        case .precipitationRisk(let probability):
            return "Rain probability: \(probability)%"
        case .highUVIndex(let index):
            return "UV Index: \(Int(index))"
        }
    }
}

struct WeatherAlert {
    let type: WeatherAlertType
    let title: String
    let message: String
    let priority: AlertPriority
}

enum WeatherAlertType {
    case criticalWind
    case severeWeather
    case extremeHeat
    case extremeCold
    case technicianSafety
}

enum AlertPriority {
    case low
    case normal
    case high
    case critical
}

enum WeatherAPIError: LocalizedError {
    case networkUnavailable
    case timeout
    case invalidResponse
    case requestFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .timeout:
            return "Weather request timed out"
        case .invalidResponse:
            return "Invalid weather data received"
        case .requestFailed(let message):
            return "Weather request failed: \(message)"
        case .unknown(let message):
            return "Unknown weather error: \(message)"
        }
    }
}

// MARK: - OpenWeatherMap One Call API 3.0 Response Types

struct OpenWeatherMapOneCallResponse: Codable {
    let lat: Double
    let lon: Double
    let timezone: String
    let timezoneOffset: Int
    let current: CurrentWeather
    let daily: [DailyWeather]

    enum CodingKeys: String, CodingKey {
        case lat, lon, timezone
        case timezoneOffset = "timezone_offset"
        case current, daily
    }

    struct CurrentWeather: Codable {
        let dt: Int
        let sunrise: Int
        let sunset: Int
        let temp: Double
        let feels_like: Double
        let pressure: Int
        let humidity: Int
        let dew_point: Double
        let uvi: Double
        let clouds: Int
        let visibility: Int
        let wind_speed: Double
        let wind_deg: Int
        let wind_gust: Double?
        let weather: [Weather]
        let rain: Rain?
        let snow: Snow?

        struct Weather: Codable {
            let id: Int
            let main: String
            let description: String
            let icon: String
        }

        struct Rain: Codable {
            let oneHour: Double

            enum CodingKeys: String, CodingKey {
                case oneHour = "1h"
            }
        }

        struct Snow: Codable {
            let oneHour: Double

            enum CodingKeys: String, CodingKey {
                case oneHour = "1h"
            }
        }
    }

    struct DailyWeather: Codable {
        let dt: Int
        let sunrise: Int
        let sunset: Int
        let moonrise: Int
        let moonset: Int
        let moon_phase: Double
        let temp: Temperature
        let feels_like: FeelsLike
        let pressure: Int
        let humidity: Int
        let dew_point: Double
        let wind_speed: Double
        let wind_deg: Int
        let wind_gust: Double?
        let weather: [CurrentWeather.Weather]
        let clouds: Int
        let pop: Double
        let rain: Double?
        let snow: Double?
        let uvi: Double

        struct Temperature: Codable {
            let day: Double
            let min: Double
            let max: Double
            let night: Double
            let eve: Double
            let morn: Double
        }

        struct FeelsLike: Codable {
            let day: Double
            let night: Double
            let eve: Double
            let morn: Double
        }
    }
}

// MARK: - Performance Monitoring Extension

// Note: trackWeatherAPICall extension is defined in PerformanceManager.swift

struct WeatherAPIMetrics {
    let success: Bool
    let dataUsage: Int
    let responseTime: TimeInterval
    let timestamp: Date
}
