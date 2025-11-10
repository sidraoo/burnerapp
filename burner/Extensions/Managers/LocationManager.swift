import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var userLocation: UserLocation?
    @Published var hasLocationPreference: Bool = false
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private let userDefaults = UserDefaults.standard
    private let geocoder = CLGeocoder()
    
    // UserDefaults keys
    private let locationTypeKey = "userLocationType"
    private let latitudeKey = "userLatitude"
    private let longitudeKey = "userLongitude"
    private let cityNameKey = "userCityName"
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Load saved location preference
        loadLocationPreference()
    }
    
    // MARK: - Location Preference Storage
    
    func loadLocationPreference() {
        if let locationType = userDefaults.string(forKey: locationTypeKey) {
            if locationType == "gps" {
                if let lat = userDefaults.object(forKey: latitudeKey) as? Double,
                   let lon = userDefaults.object(forKey: longitudeKey) as? Double {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    userLocation = .coordinate(coordinate)
                    currentLocation = CLLocation(latitude: lat, longitude: lon)
                    hasLocationPreference = true
                }
            } else if locationType == "city" {
                if let city = userDefaults.string(forKey: cityNameKey) {
                    userLocation = .city(city)
                    hasLocationPreference = true
                    // Geocode the city to get coordinates
                    geocodeCity(city)
                }
            }
        }
    }
    
    func saveLocationPreference(_ location: UserLocation) {
        userLocation = location
        hasLocationPreference = true
        
        switch location {
        case .coordinate(let coord):
            userDefaults.set("gps", forKey: locationTypeKey)
            userDefaults.set(coord.latitude, forKey: latitudeKey)
            userDefaults.set(coord.longitude, forKey: longitudeKey)
            userDefaults.removeObject(forKey: cityNameKey)
            currentLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            
        case .city(let cityName):
            userDefaults.set("city", forKey: locationTypeKey)
            userDefaults.set(cityName, forKey: cityNameKey)
            userDefaults.removeObject(forKey: latitudeKey)
            userDefaults.removeObject(forKey: longitudeKey)
            // Geocode the city
            geocodeCity(cityName)
        }
    }
    
    func clearLocationPreference() {
        userDefaults.removeObject(forKey: locationTypeKey)
        userDefaults.removeObject(forKey: latitudeKey)
        userDefaults.removeObject(forKey: longitudeKey)
        userDefaults.removeObject(forKey: cityNameKey)
        userLocation = nil
        currentLocation = nil
        hasLocationPreference = false
    }
    
    // MARK: - Location Permissions
    
    func requestLocationPermission() {
        authorizationStatus = locationManager.authorizationStatus
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            errorMessage = "Location access denied. Please enable it in Settings."
        @unknown default:
            break
        }
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Geocoding
    
    func geocodeCity(_ cityName: String, completion: ((Result<CLLocationCoordinate2D, Error>) -> Void)? = nil) {
        // Add ", UK" to ensure we search within UK
        let searchString = cityName.contains("UK") ? cityName : "\(cityName), UK"
        
        geocoder.geocodeAddressString(searchString) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.errorMessage = "Could not find location: \(cityName)"
                    completion?(.failure(error))
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    let error = NSError(domain: "LocationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No location found"])
                    self.errorMessage = "Could not find location: \(cityName)"
                    completion?(.failure(error))
                    return
                }
                
                // Verify the location is in the UK
                if let country = placemark.country, country == "United Kingdom" {
                    self.currentLocation = location
                    completion?(.success(location.coordinate))
                } else {
                    let error = NSError(domain: "LocationManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Location not in UK"])
                    self.errorMessage = "Please enter a location within the UK"
                    completion?(.failure(error))
                }
            }
        }
    }
    
    func validateUKLocation(coordinate: CLLocationCoordinate2D, completion: @escaping (Bool) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            Task { @MainActor in
                if let placemark = placemarks?.first,
                   let country = placemark.country {
                    completion(country == "United Kingdom")
                } else {
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Distance Calculation
    
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }
    
    func formattedDistance(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let distance = distance(to: coordinate) else { return nil }
        
        // Convert to miles
        let miles = distance / 1609.34
        
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                startUpdatingLocation()
            case .denied, .restricted:
                errorMessage = "Location access denied. Please enable it in Settings."
                stopUpdatingLocation()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            
            // Only update if we're using GPS location
            if case .coordinate = userLocation {
                currentLocation = location
                
                // Validate it's in the UK
                validateUKLocation(coordinate: location.coordinate) { isUK in
                    if !isUK {
                        Task { @MainActor in
                            self.errorMessage = "Your current location is outside the UK"
                            self.stopUpdatingLocation()
                        }
                    }
                }
            } else if userLocation == nil {
                // First time getting location
                currentLocation = location
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = "Failed to get location: \(error.localizedDescription)"
        }
    }
}

// MARK: - UserLocation Enum

enum UserLocation: Codable, Equatable {
    case coordinate(CLLocationCoordinate2D)
    case city(String)
    
    enum CodingKeys: String, CodingKey {
        case type
        case latitude
        case longitude
        case cityName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        if type == "coordinate" {
            let lat = try container.decode(Double.self, forKey: .latitude)
            let lon = try container.decode(Double.self, forKey: .longitude)
            self = .coordinate(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        } else {
            let city = try container.decode(String.self, forKey: .cityName)
            self = .city(city)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .coordinate(let coord):
            try container.encode("coordinate", forKey: .type)
            try container.encode(coord.latitude, forKey: .latitude)
            try container.encode(coord.longitude, forKey: .longitude)
        case .city(let cityName):
            try container.encode("city", forKey: .type)
            try container.encode(cityName, forKey: .cityName)
        }
    }
}

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
