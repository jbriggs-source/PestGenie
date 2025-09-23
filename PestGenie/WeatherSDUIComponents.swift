import Foundation
import SwiftUI
import CoreLocation

// MARK: - Weather Threshold Configuration

/// Weather safety thresholds for SDUI components
struct SDUIWeatherThresholds: Codable {
    let maxWindSpeed: Double // mph
    let minTemperature: Double // Fahrenheit
    let maxTemperature: Double // Fahrenheit
    let maxHumidity: Int // percentage
    let maxPrecipitationProbability: Int // percentage
    let maxUVIndex: Double
    let minVisibility: Double // meters

    init(
        maxWindSpeed: Double = 15,
        minTemperature: Double = 45,
        maxTemperature: Double = 90,
        maxHumidity: Int = 85,
        maxPrecipitationProbability: Int = 30,
        maxUVIndex: Double = 8,
        minVisibility: Double = 1000
    ) {
        self.maxWindSpeed = maxWindSpeed
        self.minTemperature = minTemperature
        self.maxTemperature = maxTemperature
        self.maxHumidity = maxHumidity
        self.maxPrecipitationProbability = maxPrecipitationProbability
        self.maxUVIndex = maxUVIndex
        self.minVisibility = minVisibility
    }
}

// MARK: - Weather SDUI Context

/// Context for weather-related SDUI components
@MainActor
final class WeatherSDUIContext: ObservableObject {
    @Published var currentWeather: WeatherData?
    @Published var forecast: [WeatherForecast] = []
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var safetyAnalysis: TreatmentSafetyResult?
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?

    private let weatherAPI = WeatherAPI.shared
    private let locationManager = LocationManager()

    init() {
        setupLocationMonitoring()
    }

    private func setupLocationMonitoring() {
        // Monitor location changes for weather updates
        NotificationCenter.default.addObserver(
            forName: .locationUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let location = notification.object as? CLLocation {
                Task {
                    await self?.updateWeatherForLocation(location.coordinate)
                }
            }
        }
    }

    func updateWeatherForLocation(_ location: CLLocationCoordinate2D) async {
        isLoading = true

        do {
            // Fetch current weather
            currentWeather = try await weatherAPI.fetchCurrentWeather(for: location)

            // Fetch forecast
            forecast = try await weatherAPI.fetchWeatherForecast(for: location)

            // Analyze safety conditions
            if let weather = currentWeather {
                safetyAnalysis = weatherAPI.checkTreatmentSafety(for: weather)

                // Check for weather alerts
                if let alert = weatherAPI.shouldSendWeatherAlert(for: weather) {
                    weatherAlerts.append(alert)
                }
            }

            lastUpdateTime = Date()
        } catch {
            print("Failed to update weather: \(error)")
        }

        isLoading = false
    }

    func refreshWeather() async {
        // Use current location or job location
        if let currentLocation = locationManager.currentLocation {
            await updateWeatherForLocation(currentLocation.coordinate)
        }
    }

    func getWeatherMetricValue(for metric: String) -> String {
        guard let weather = currentWeather else { return "N/A" }

        switch metric.lowercased() {
        case "temperature":
            return "\(Int(weather.temperature))°F"
        case "humidity":
            return "\(weather.humidity)%"
        case "wind_speed":
            return "\(Int(weather.windSpeed)) mph"
        case "wind_direction":
            return windDirectionString(weather.windDirection)
        case "precipitation":
            return "\(weather.precipitationProbability)%"
        case "uv_index":
            return "\(Int(weather.uvIndex))"
        case "visibility":
            return "\(Int(weather.visibility/1609)) mi"
        case "pressure":
            return String(format: "%.2f inHg", weather.pressure)
        case "feels_like":
            return "\(Int(weather.feelsLike))°F"
        default:
            return "N/A"
        }
    }

    private func windDirectionString(_ degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }
}

// MARK: - Weather Component Renderers

extension SDUIScreenRenderer {
    static func renderWeatherDashboard(_ component: SDUIComponent, context: SDUIContext) -> AnyView {
        AnyView(WeatherDashboardView(component: component, context: context))
    }

    static func renderWeatherAlert(_ component: SDUIComponent, context: SDUIContext) -> AnyView {
        AnyView(WeatherAlertView(component: component, context: context))
    }

    static func renderWeatherForecast(_ component: SDUIComponent, context: SDUIContext) -> AnyView {
        AnyView(WeatherForecastView(component: component, context: context))
    }

    static func renderWeatherMetrics(_ component: SDUIComponent, context: SDUIContext) -> AnyView {
        AnyView(WeatherMetricsView(component: component, context: context))
    }

    static func renderSafetyIndicator(_ component: SDUIComponent, context: SDUIContext) -> AnyView {
        AnyView(SafetyIndicatorView(component: component, context: context))
    }

    static func renderTreatmentConditions(_ component: SDUIComponent, context: SDUIContext) -> AnyView {
        AnyView(TreatmentConditionsView(component: component, context: context))
    }
}

// MARK: - Weather Dashboard View

struct WeatherDashboardView: View {
    let component: SDUIComponent
    let context: SDUIContext
    @StateObject private var weatherContext = WeatherSDUIContext()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Weather Conditions")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if weatherContext.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Refresh") {
                        Task {
                            await weatherContext.refreshWeather()
                        }
                    }
                    .font(.caption)
                }
            }

            // Current Conditions
            if let weather = weatherContext.currentWeather {
                currentWeatherCard(weather)
            } else {
                placeholderCard()
            }

            // Safety Analysis
            if let analysis = weatherContext.safetyAnalysis {
                safetyAnalysisCard(analysis)
            }

            // Weather Alerts
            if !weatherContext.weatherAlerts.isEmpty {
                weatherAlertsSection()
            }

            // Last Updated
            if let lastUpdate = weatherContext.lastUpdateTime {
                Text("Last updated: \(formatUpdateTime(lastUpdate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
        .task {
            await weatherContext.refreshWeather()
        }
    }

    private func currentWeatherCard(_ weather: WeatherData) -> some View {
        HStack(spacing: 20) {
            // Temperature and condition
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(weather.temperature))°F")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text(weather.description.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Feels like \(Int(weather.feelsLike))°F")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Key metrics
            VStack(alignment: .trailing, spacing: 8) {
                weatherMetricRow("Wind", "\(Int(weather.windSpeed)) mph")
                weatherMetricRow("Humidity", "\(weather.humidity)%")
                weatherMetricRow("UV Index", "\(Int(weather.uvIndex))")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func weatherMetricRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func safetyAnalysisCard(_ analysis: TreatmentSafetyResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: analysis.canTreat ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(analysis.canTreat ? .green : .red)

                Text(analysis.canTreat ? "Safe for Treatment" : "Unsafe Conditions")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()
            }

            if !analysis.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(analysis.warnings, id: \.title) { warning in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(warning.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if !analysis.recommendedActions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommendations:")
                        .font(.caption)
                        .fontWeight(.medium)

                    ForEach(analysis.recommendedActions, id: \.self) { action in
                        Text("• \(action)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(analysis.canTreat ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
    }

    private func weatherAlertsSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weather Alerts")
                .font(.headline)
                .fontWeight(.medium)

            ForEach(weatherContext.weatherAlerts, id: \.title) { alert in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(alert.priority == .critical ? .red : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(alert.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func placeholderCard() -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading weather data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func formatUpdateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Weather Alert View

struct WeatherAlertView: View {
    let component: SDUIComponent
    let context: SDUIContext
    @StateObject private var weatherContext = WeatherSDUIContext()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !weatherContext.weatherAlerts.isEmpty {
                ForEach(weatherContext.weatherAlerts, id: \.title) { alert in
                    alertCard(alert)
                }
            } else {
                Text("No weather alerts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    private func alertCard(_ alert: WeatherAlert) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForAlertType(alert.type))
                .foregroundColor(colorForPriority(alert.priority))
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(alert.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColorForPriority(alert.priority))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorForPriority(alert.priority), lineWidth: 1)
        )
    }

    private func iconForAlertType(_ type: WeatherAlertType) -> String {
        switch type {
        case .criticalWind: return "wind"
        case .severeWeather: return "cloud.heavyrain.fill"
        case .extremeHeat: return "thermometer.sun.fill"
        case .extremeCold: return "thermometer.snowflake"
        case .technicianSafety: return "person.fill.badge.minus"
        }
    }

    private func colorForPriority(_ priority: AlertPriority) -> Color {
        switch priority {
        case .low: return .blue
        case .normal: return .orange
        case .high: return .red
        case .critical: return .red
        }
    }

    private func backgroundColorForPriority(_ priority: AlertPriority) -> Color {
        switch priority {
        case .low: return Color.blue.opacity(0.1)
        case .normal: return Color.orange.opacity(0.1)
        case .high: return Color.red.opacity(0.1)
        case .critical: return Color.red.opacity(0.15)
        }
    }
}

// MARK: - Weather Metrics View

struct WeatherMetricsView: View {
    let component: SDUIComponent
    let context: SDUIContext
    @StateObject private var weatherContext = WeatherSDUIContext()

    private var metricsToShow: [String] {
        component.weatherMetrics ?? ["temperature", "humidity", "wind_speed", "precipitation"]
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            ForEach(metricsToShow, id: \.self) { metric in
                metricCard(metric)
            }
        }
    }

    private func metricCard(_ metric: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: iconForMetric(metric))
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(labelForMetric(metric))
                .font(.caption)
                .foregroundColor(.secondary)

            Text(weatherContext.getWeatherMetricValue(for: metric))
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func iconForMetric(_ metric: String) -> String {
        switch metric.lowercased() {
        case "temperature": return "thermometer"
        case "humidity": return "humidity.fill"
        case "wind_speed": return "wind"
        case "wind_direction": return "safari.fill"
        case "precipitation": return "cloud.rain.fill"
        case "uv_index": return "sun.max.fill"
        case "visibility": return "eye.fill"
        case "pressure": return "gauge"
        case "feels_like": return "thermometer.medium"
        default: return "questionmark.circle"
        }
    }

    private func labelForMetric(_ metric: String) -> String {
        switch metric.lowercased() {
        case "temperature": return "Temperature"
        case "humidity": return "Humidity"
        case "wind_speed": return "Wind Speed"
        case "wind_direction": return "Wind Direction"
        case "precipitation": return "Rain Chance"
        case "uv_index": return "UV Index"
        case "visibility": return "Visibility"
        case "pressure": return "Pressure"
        case "feels_like": return "Feels Like"
        default: return metric.capitalized
        }
    }
}

// MARK: - Safety Indicator View

struct SafetyIndicatorView: View {
    let component: SDUIComponent
    let context: SDUIContext
    @StateObject private var weatherContext = WeatherSDUIContext()

    var body: some View {
        VStack(spacing: 12) {
            if let analysis = weatherContext.safetyAnalysis {
                HStack {
                    Circle()
                        .fill(analysis.canTreat ? Color.green : Color.red)
                        .frame(width: 12, height: 12)

                    Text(analysis.canTreat ? "SAFE" : "UNSAFE")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(analysis.canTreat ? .green : .red)

                    Spacer()
                }

                if !analysis.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(analysis.warnings, id: \.title) { warning in
                            Text("⚠️ \(warning.title)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            } else {
                HStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 12, height: 12)

                    Text("CHECKING...")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)

                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Treatment Conditions View

struct TreatmentConditionsView: View {
    let component: SDUIComponent
    let context: SDUIContext
    @StateObject private var weatherContext = WeatherSDUIContext()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Treatment Conditions")
                .font(.headline)
                .fontWeight(.semibold)

            if let analysis = weatherContext.safetyAnalysis {
                conditionsGrid(analysis)

                if !analysis.recommendedActions.isEmpty {
                    recommendationsSection(analysis.recommendedActions)
                }
            } else {
                ProgressView("Analyzing conditions...")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 1)
        )
    }

    private func conditionsGrid(_ analysis: TreatmentSafetyResult) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            conditionCard("Liquid Treatments", analysis.canTreat, "drop.fill")
            conditionCard("Granular Treatments", analysis.canTreat, "circle.hexagongrid.fill")
            conditionCard("Spray Equipment", analysis.canTreat, "sprinkler.and.droplets.fill")
            conditionCard("Overall Safety", analysis.canTreat, "shield.fill")
        }
    }

    private func conditionCard(_ title: String, _ isAllowed: Bool, _ icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isAllowed ? .green : .red)

            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Text(isAllowed ? "Allowed" : "Not Recommended")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isAllowed ? .green : .red)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isAllowed ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
    }

    private func recommendationsSection(_ recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(recommendations, id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.accentColor)
                    Text(recommendation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Weather Forecast View

struct WeatherForecastView: View {
    let component: SDUIComponent
    let context: SDUIContext
    @StateObject private var weatherContext = WeatherSDUIContext()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weather Forecast")
                .font(.headline)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(weatherContext.forecast.prefix(5), id: \.id) { forecast in
                        forecastCard(forecast)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func forecastCard(_ forecast: WeatherForecast) -> some View {
        VStack(spacing: 8) {
            Text(dayLabel(for: forecast.date))
                .font(.caption)
                .fontWeight(.medium)

            Image(systemName: iconForCondition(forecast.condition))
                .font(.title2)
                .foregroundColor(.accentColor)

            Text("\(Int(forecast.temperature))°")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("\(forecast.precipitationProbability)%")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
        .frame(width: 80)
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func iconForCondition(_ condition: String) -> String {
        switch condition.lowercased() {
        case "clear": return "sun.max.fill"
        case "clouds": return "cloud.fill"
        case "rain": return "cloud.rain.fill"
        case "drizzle": return "cloud.drizzle.fill"
        case "thunderstorm": return "cloud.bolt.fill"
        case "snow": return "cloud.snow.fill"
        case "mist", "fog": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let locationUpdated = Notification.Name("locationUpdated")
}