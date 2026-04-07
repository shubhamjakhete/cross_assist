//
//  LocationManager.swift
//  CrossAssist
//

import Combine
import CoreLocation
import MapKit

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = LocationManager()

    @Published var currentLocation: CLLocation?
    @Published var cityName: String = "Locating..."
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationAvailable: Bool = false

    private let locationManager = CLLocationManager()
    private var lastGeocodedLocation: CLLocation?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            isLocationAvailable = true
        case .denied, .restricted:
            isLocationAvailable = false
            cityName = "Location off"
        @unknown default:
            break
        }
    }

    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isLocationAvailable = true
                manager.startUpdatingLocation()
            case .denied, .restricted:
                self.isLocationAvailable = false
                self.cityName = "Location off"
            default:
                break
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.isLocationAvailable = true
            self.reverseGeocode(location)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.cityName = "Location unavailable"
            self.isLocationAvailable = false
        }
    }

    // MARK: - Reverse geocoding

    private func reverseGeocode(_ location: CLLocation) {
        if let last = lastGeocodedLocation,
           location.distance(from: last) < 200 { return }

        lastGeocodedLocation = location

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    self.cityName = "Location unavailable"
                    return
                }
                let mapItems = try await request.mapItems
                guard let item = mapItems.first else {
                    self.cityName = "Location unavailable"
                    return
                }

                if let reps = item.addressRepresentations {
                    if let contextual = reps.cityWithContext(.short)
                        ?? reps.cityWithContext(.automatic)
                        ?? reps.cityWithContext(.full) {
                        self.cityName = contextual
                    } else if let city = reps.cityName {
                        let state = reps.regionName ?? ""
                        self.cityName = state.isEmpty ? city : "\(city), \(state)"
                    } else {
                        self.cityName = Self.cityNameFromAddress(item.address)
                    }
                } else {
                    self.cityName = Self.cityNameFromAddress(item.address)
                }
            } catch {
                self.cityName = "Location unavailable"
            }
        }
    }

    /// Prefer `MKAddress` short/full strings (iOS 26+); avoids deprecated `MKMapItem.placemark`.
    private static func cityNameFromAddress(_ address: MKAddress?) -> String {
        guard let address else { return "Unknown" }
        if let short = address.shortAddress, !short.isEmpty { return short }
        if !address.fullAddress.isEmpty { return address.fullAddress }
        return "Unknown"
    }
}
