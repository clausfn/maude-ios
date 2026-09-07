import Testing
import Foundation
@testable import Maude

// External weather/AQI context — RTM: FR-CTX-01, NFR-PRIV (no precise location / no health egress).
struct WeatherContextTests {

    // T-CTX-01 — coordinates are coarsened to ~0.1° before any request.
    @Test func coordinateIsCoarsened() {
        let precise = Coordinate(latitude: 55.67610, longitude: 12.56830)
        let coarse = precise.coarsened()
        #expect(coarse.latitude == 55.7)
        #expect(coarse.longitude == 12.6)
    }

    // T-CTX-02 — request URLs carry ONLY lat/lon + named env fields (no health,
    // no identifiers). Proves "no health egress" at the URL level.
    @Test func requestUrlsCarryOnlyEnvFields() {
        let c = Coordinate(latitude: 55.7, longitude: 12.6)
        let names = Set(
            (URLComponents(url: OpenMeteo.forecastURL(c), resolvingAgainstBaseURL: false)?.queryItems ?? [])
                .map(\.name)
            + (URLComponents(url: OpenMeteo.airQualityURL(c), resolvingAgainstBaseURL: false)?.queryItems ?? [])
                .map(\.name))
        #expect(names == ["latitude", "longitude", "current"])
        #expect(OpenMeteo.forecastURL(c).host == "api.open-meteo.com")
        #expect(OpenMeteo.airQualityURL(c).host == "air-quality-api.open-meteo.com")
    }

    // T-CTX-03 — mock provider returns a usable snapshot offline.
    @Test func mockProviderReturnsSnapshot() async throws {
        let snap = try await MockWeatherProvider().fetch(at: Coordinate(latitude: 0, longitude: 0))
        #expect(snap.tempC != nil)
        #expect(snap.aqi != nil)
    }

    // T-CTX-04 — snapshot maps to a WeatherContext with provenance EXTERNAL.
    @Test func mapsToExternalProvenanceEntity() throws {
        let snap = MockWeatherProvider().snapshot
        let entity = try WeatherContextMapper.entity(from: snap)
        #expect(entity.provenance == .external)
        #expect(entity.source == "Open-Meteo")
        #expect(entity.tempC == snap.tempC)
    }
}
