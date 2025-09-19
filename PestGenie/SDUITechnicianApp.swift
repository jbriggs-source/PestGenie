import SwiftUI

/// Entry point for the SDUI Technician mobile application. The app fetches UI
/// configuration from a JSON file (or backend) and renders screens dynamically
/// based on the server provided structure. It still leverages a view model for
/// domain data like jobs, timestamps and signatures, but the presentation
/// details are defined by the JSON specification.
@main
struct SDUITechnicianApp: App {
    @StateObject private var routeViewModel = RouteViewModel()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                SDUIContentView()
                    .environmentObject(routeViewModel)
                    .environmentObject(locationManager)
            }
        }
    }
}