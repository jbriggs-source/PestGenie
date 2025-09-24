import SwiftUI

/// Entry point for the SDUI Technician mobile application. The app features an
/// engaging home dashboard with quick access to routes, equipment, chemicals,
/// and profile management. The UI configuration can be server-driven via JSON
/// files while maintaining domain data through view models.
@main
struct SDUITechnicianApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}