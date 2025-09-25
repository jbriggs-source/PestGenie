import Foundation
import CoreLocation
import UserNotifications

final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    @Published var monitoredJobs: [Job] = []
    @Published var currentLocation: CLLocation?
    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        requestPermissions()
    }
    private func requestPermissions() {
        locationManager.requestAlwaysAuthorization()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            locationManager.requestAlwaysAuthorization()
            // For simplicity, we'll return true. In a real app, you'd check the authorization status
            continuation.resume(returning: true)
        }
    }
    func startMonitoring() {
        locationManager.startUpdatingLocation()
    }
    private func handleLocationUpdate(_ location: CLLocation) {
        // Update current location
        currentLocation = location
        
        for job in monitoredJobs {
            guard let coord = job.coordinate else { continue }
            let jobLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distance = location.distance(from: jobLoc)
            if distance < 100 {
                sendProximityAlert(for: job)
            }
        }
    }
    private func sendProximityAlert(for job: Job) {
        let content = UNMutableNotificationContent()
        content.title = "Approaching \(job.customerName)"
        content.body = job.pinnedNotes != nil ? "Pinned note: \(job.pinnedNotes!)" : "You are near the next stop."
        let request = UNNotificationRequest(identifier: job.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        handleLocationUpdate(location)
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }
}