// WeatherContext.swift — L1 external-context value types (portable).
//
// One external signal for MVP (FR-CTX-01): Open-Meteo weather + air quality.
// Privacy posture: the coordinate is COARSENED to ~0.1° (~11 km) before any
// request, the fetch is per-session (not stored as a profile), and NO health
// data is ever included in the request. Open-Meteo is keyless and EU-hosted.
// Pure Foundation (Android-portable). provenance = EXTERNAL at the entity layer.
import Foundation

public struct Coordinate: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude; self.longitude = longitude
    }

    /// Coarsen to `decimals` places (default 1 ⇒ ~11 km) so precise location
    /// never leaves the device. This is a privacy control, not cosmetic.
    public func coarsened(toDecimals decimals: Int = 1) -> Coordinate {
        let f = pow(10.0, Double(decimals))
        return Coordinate(latitude: (latitude * f).rounded() / f,
                          longitude: (longitude * f).rounded() / f)
    }
}

/// Per-session weather/AQI reading. Carries only environmental values + the
/// coarse coordinate actually used — never a health value.
public struct WeatherSnapshot: Sendable, Equatable {
    public let ts: Date
    public let tempC: Double?
    public let precipMm: Double?
    public let aqi: Int?          // European AQI, when air-quality succeeded
    public let coordinate: Coordinate   // the COARSE coordinate sent upstream
    public init(ts: Date, tempC: Double?, precipMm: Double?, aqi: Int?, coordinate: Coordinate) {
        self.ts = ts; self.tempC = tempC; self.precipMm = precipMm
        self.aqi = aqi; self.coordinate = coordinate
    }
}

public enum WeatherContextError: Error, Equatable, Sendable {
    case badResponse
}

public protocol WeatherContextProvider: Sendable {
    func fetch(at coordinate: Coordinate) async throws -> WeatherSnapshot
}
