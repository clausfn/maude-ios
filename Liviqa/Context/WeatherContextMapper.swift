// WeatherContextMapper.swift — WeatherSnapshot → WeatherContext entity.
//
// The only place the per-session snapshot becomes a stored row. provenance is
// EXTERNAL (set by the entity's defaults). The coarse coordinate is NOT
// persisted — we keep only the environmental values the app actually uses.
import Foundation
import SwiftData

enum WeatherContextMapper {
    static func entity(from s: WeatherSnapshot) throws -> WeatherContext {
        try WeatherContext(ts: s.ts, tempC: s.tempC, precipMm: s.precipMm, aqi: s.aqi)
    }
}
