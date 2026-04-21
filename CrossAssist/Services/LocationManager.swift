//
//  LocationManager.swift
//  CrossAssist
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

// MARK: - One-shot location (no persistent CLLocationManager on LocationManager)

/// Short-lived `CLLocationManager` for a single `requestLocation()` / authorization flow (iOS 26 When Shared).
private final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var didFinish = false
    private let onResult: (Result<CLLocationCoordinate2D, Error>) -> Void

    init(onResult: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        self.onResult = onResult
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(NSError(domain: "Location", code: 1, userInfo: [NSLocalizedDescriptionKey: "Denied or restricted"])))
        @unknown default:
            manager.requestWhenInUseAuthorization()
        }
    }

    private func finish(_ result: Result<CLLocationCoordinate2D, Error>) {
        guard !didFinish else { return }
        didFinish = true
        Task { @MainActor in
            self.onResult(result)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(NSError(domain: "Location", code: 1, userInfo: [NSLocalizedDescriptionKey: "Denied or restricted"])))
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        finish(.success(coord))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }
}

// MARK: - LocationManager (MKCoordinateRegion + Map(position:) — no stored CLLocationManager)

@MainActor
final class LocationManager: ObservableObject {

    static let shared = LocationManager()

    /// Map region; drives `Map(position: .constant(.region(...)))` on Home.
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.8703, longitude: -117.9242),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @Published var cityName: String = "Locating..."
    @Published var isLocationActive: Bool = false
    @Published var userCoordinate: CLLocationCoordinate2D?

    private static let fallbackCenter = CLLocationCoordinate2D(latitude: 33.8703, longitude: -117.9242)
    private static let fallbackSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)

    private static var fallbackRegion: MKCoordinateRegion {
        MKCoordinateRegion(center: fallbackCenter, span: fallbackSpan)
    }

    private var oneShot: OneShotLocationFetcher?

    private init() {}

    /// Call from the map card location button to trigger When Shared / one-shot fix.
    func requestUserLocation() {
        let fetcher = OneShotLocationFetcher { [weak self] result in
            guard let self else { return }
            self.oneShot = nil
            switch result {
            case .success(let coordinate):
                self.userDidShareLocation(coordinate: coordinate)
            case .failure:
                self.isLocationActive = false
                self.userCoordinate = nil
                self.cityName = "Tap location button"
                self.region = Self.fallbackRegion
            }
        }
        oneShot = fetcher
        fetcher.start()
    }

    /// MapKit / one-shot pipeline delivered a coordinate.
    func userDidShareLocation(coordinate: CLLocationCoordinate2D) {
        userCoordinate = coordinate
        isLocationActive = true
        withAnimation(.easeInOut(duration: 0.45)) {
            self.region = MKCoordinateRegion(center: coordinate, span: Self.fallbackSpan)
        }
        reverseGeocode(coordinate)
    }

    func reset() {
        userCoordinate = nil
        isLocationActive = false
        cityName = "Locating..."
        region = Self.fallbackRegion
    }

    // MARK: - Reverse geocode (MapKit on iOS 18+, CLGeocoder fallback)

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        if #available(iOS 18, *) {
            Task {
                do {
                    let location = CLLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    guard let request = MKReverseGeocodingRequest(location: location) else {
                        await MainActor.run { self.cityName = "Location active" }
                        return
                    }
                    let mapItems = try await request.mapItems
                    await MainActor.run {
                        guard let item = mapItems.first else {
                            self.cityName = "Location active"
                            return
                        }
                        if let reps = item.addressRepresentations {
                            if let line = reps.cityWithContext(.full)
                                ?? reps.cityWithContext(.automatic) {
                                self.cityName = line
                            } else {
                                let city = reps.cityName ?? "Unknown"
                                let region = reps.regionName ?? ""
                                self.cityName = region.isEmpty ? city : "\(city), \(region)"
                            }
                        } else if let addr = item.address {
                            let line = addr.shortAddress ?? addr.fullAddress
                            if !line.isEmpty {
                                self.cityName = line
                            } else {
                                self.cityName = "Location active"
                            }
                        } else {
                            self.cityName = "Location active"
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.cityName = "Location active"
                    }
                }
            }
        } else {
            Task {
                do {
                    let cityString = try await withCheckedThrowingContinuation {
                        (continuation: CheckedContinuation<String, Error>) in
                        CLGeocoder().reverseGeocodeLocation(
                            CLLocation(
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude
                            )
                        ) { placemarks, error in
                            if let error {
                                continuation.resume(throwing: error)
                                return
                            }
                            let city = placemarks?.first?.locality
                                ?? placemarks?.first?.subAdministrativeArea
                                ?? placemarks?.first?.administrativeArea
                                ?? "Unknown"
                            let state = placemarks?.first?
                                .administrativeArea ?? ""
                            let name = state.isEmpty
                                ? city : "\(city), \(state)"
                            continuation.resume(returning: name)
                        }
                    }
                    await MainActor.run {
                        self.cityName = cityString
                    }
                } catch {
                    await MainActor.run {
                        self.cityName = "Location active"
                    }
                }
            }
        }
    }
}
