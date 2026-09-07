// OpenMeteoWeatherProvider.swift — FR-CTX-01 external context fetch.
//
// Builds the request from a COARSE coordinate only (privacy), fetches current
// weather + European AQI from Open-Meteo, and returns a per-session snapshot.
// Air-quality failure is non-fatal (aqi stays nil). No health data, no API key,
// no profile persisted upstream. URL construction is a pure, testable function.
import Foundation

/// Pure URL builders — unit-testable proof that requests carry only lat/lon +
/// the named environmental fields (no health data, no identifiers).
public enum OpenMeteo {
    public static let weatherHost = "api.open-meteo.com"
    public static let airHost = "air-quality-api.open-meteo.com"

    public static func forecastURL(_ c: Coordinate) -> URL {
        var comp = URLComponents()
        comp.scheme = "https"; comp.host = weatherHost; comp.path = "/v1/forecast"
        comp.queryItems = [
            .init(name: "latitude", value: String(c.latitude)),
            .init(name: "longitude", value: String(c.longitude)),
            .init(name: "current", value: "temperature_2m,precipitation"),
        ]
        return comp.url!
    }

    public static func airQualityURL(_ c: Coordinate) -> URL {
        var comp = URLComponents()
        comp.scheme = "https"; comp.host = airHost; comp.path = "/v1/air-quality"
        comp.queryItems = [
            .init(name: "latitude", value: String(c.latitude)),
            .init(name: "longitude", value: String(c.longitude)),
            .init(name: "current", value: "european_aqi"),
        ]
        return comp.url!
    }
}

private struct OMForecast: Decodable {
    struct Current: Decodable { let temperature_2m: Double?; let precipitation: Double? }
    let current: Current?
}
private struct OMAir: Decodable {
    struct Current: Decodable { let european_aqi: Double? }
    let current: Current?
}

public struct OpenMeteoWeatherProvider: WeatherContextProvider {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func fetch(at coordinate: Coordinate) async throws -> WeatherSnapshot {
        let coarse = coordinate.coarsened()   // privacy: never send precise location

        let (wData, wResp) = try await session.data(from: OpenMeteo.forecastURL(coarse))
        guard (wResp as? HTTPURLResponse)?.statusCode == 200 else {
            throw WeatherContextError.badResponse
        }
        let forecast = try JSONDecoder().decode(OMForecast.self, from: wData)

        // Air quality is best-effort; never fail the whole snapshot on it.
        var aqi: Int? = nil
        if let (aData, aResp) = try? await session.data(from: OpenMeteo.airQualityURL(coarse)),
           (aResp as? HTTPURLResponse)?.statusCode == 200,
           let air = try? JSONDecoder().decode(OMAir.self, from: aData),
           let value = air.current?.european_aqi {
            aqi = Int(value.rounded())
        }

        return WeatherSnapshot(
            ts: Date(),
            tempC: forecast.current?.temperature_2m,
            precipMm: forecast.current?.precipitation,
            aqi: aqi,
            coordinate: coarse)
    }
}

/// Offline/test double — fixed snapshot, no network.
public struct MockWeatherProvider: WeatherContextProvider {
    public let snapshot: WeatherSnapshot
    public init(snapshot: WeatherSnapshot = WeatherSnapshot(
        ts: Date(timeIntervalSince1970: 1_750_000_000), tempC: 14.2, precipMm: 0.0,
        aqi: 38, coordinate: Coordinate(latitude: 55.7, longitude: 12.6))) {
        self.snapshot = snapshot
    }
    public func fetch(at coordinate: Coordinate) async throws -> WeatherSnapshot { snapshot }
}
