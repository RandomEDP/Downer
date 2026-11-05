import CoreLocation
import MapKit
import Observation

struct PubSuggestion: Identifiable, Hashable, Sendable {
    let title: String
    let subtitle: String
    var id: String { title + "\n" + subtitle }
}

/// Type-ahead search for pubs and bars near the user, using Apple Maps.
@MainActor
@Observable
final class PubSearch: NSObject {
    var query = "" {
        didSet { completer.queryFragment = query }
    }
    private(set) var suggestions: [PubSuggestion] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private let locationManager = CLLocationManager()

    override init() {
        super.init()
        completer.resultTypes = .pointOfInterest
        completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [.nightlife, .brewery, .restaurant, .winery])
        completer.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Biases results to where the user is, asking for location the first time.
    func start() {
        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: locationManager.requestLocation()
        default: break
        }
    }

    private func focus(on coordinate: CLLocationCoordinate2D) {
        completer.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 20_000, longitudinalMeters: 20_000)
        if !query.isEmpty { completer.queryFragment = query }
    }
}

extension PubSearch: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.map { PubSuggestion(title: $0.title, subtitle: $0.subtitle) }
        MainActor.assumeIsolated { suggestions = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        MainActor.assumeIsolated { suggestions = [] }
    }
}

extension PubSearch: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        MainActor.assumeIsolated { focus(on: coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
}
