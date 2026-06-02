// LifestyleModels.swift — Extended model types for MVP screens · v01 2026-05-22
// Covers: backup preference, data sources, health passport, correlation grid, token transactions.
import Foundation
import SwiftUI

// MARK: - Backup Preference

enum BackupPreference: String, CaseIterable, Codable {
    case onDevice  = "on_device"
    case iCloud    = "icloud"
    case sovereign = "sovereign"

    var label: String {
        switch self {
        case .onDevice:  return "On device only"
        case .iCloud:    return "iCloud (encrypted)"
        case .sovereign: return "Sovereign cloud"
        }
    }

    var description: String {
        switch self {
        case .onDevice:
            return "Your data never leaves this device. No backup — if you lose your phone, your history is gone."
        case .iCloud:
            return "Encrypted end-to-end backup in your personal iCloud. Only you can decrypt it."
        case .sovereign:
            return "Stored in a GDPR-compliant European cloud data space. You choose the region and operator."
        }
    }

    var icon: String {
        switch self {
        case .onDevice:  return "iphone"
        case .iCloud:    return "lock.icloud"
        case .sovereign: return "server.rack"
        }
    }
}

// MARK: - Data Source Connection

enum SourceCategory: String, CaseIterable {
    case health     = "Health"
    case financial  = "Financial"
    case context    = "Context"
    case device     = "Device"
}

struct DataSourceConnection: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let iconColorHex: UInt32
    let category: SourceCategory
    var isConnected: Bool
    var lastSync: Date?
    let dataDescription: String   // what gets pulled — never say "personal data"
    let privacyNote: String       // on-device processing note

    var iconColor: Color { Color(hex: iconColorHex) }

    init(id: UUID = UUID(), name: String, icon: String, iconColorHex: UInt32,
         category: SourceCategory, isConnected: Bool, lastSync: Date? = nil,
         dataDescription: String, privacyNote: String) {
        self.id              = id
        self.name            = name
        self.icon            = icon
        self.iconColorHex    = iconColorHex
        self.category        = category
        self.isConnected     = isConnected
        self.lastSync        = lastSync
        self.dataDescription = dataDescription
        self.privacyNote     = privacyNote
    }
}

// MARK: - Health Passport Stats

struct PassportStats {
    let totalReadings:      Int
    let nudgesGenerated:    Int
    let sourcesConnected:   Int
    let daysTracked:        Int
    let glucoseTimeInRange: Int     // 0–100 percentage
    let avgSleepHours:      Double  // e.g. 7.08
    let journalEntries:     Int
    let consentDecisions:   Int
}

// MARK: - Correlation Grid

/// Heat-map intensity for one cell in the 7-day correlation grid.
enum CorrelationLevel: Int, CaseIterable {
    case noData  = 0
    case low     = 1
    case medium  = 2
    case high    = 3
    case outlier = 4    // notable deviation from personal baseline

    var color: Color {
        switch self {
        case .noData:  return Color(hex: 0xEAE5DB)          // LiviqaTheme.line2
        case .low:     return Color(hex: 0xC7DCCD)          // LiviqaTheme.moss3
        case .medium:  return Color(hex: 0x3D7A5A).opacity(0.45)
        case .high:    return Color(hex: 0x3D7A5A)          // LiviqaTheme.moss
        case .outlier: return Color(hex: 0xC47D11)          // LiviqaTheme.amber
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .noData:  return "no data"
        case .low:     return "low"
        case .medium:  return "moderate"
        case .high:    return "high"
        case .outlier: return "outlier"
        }
    }
}

/// One day column in the grid. `values` order: glucose, sleep, hrv, exercise, spending, calendar, weather.
struct CorrelationDay: Identifiable {
    let id = UUID()
    let dayLabel: String    // "M" … "S"
    let dateOffset: Int     // days before today (0 = today)
    let values: [CorrelationLevel]   // must be exactly 7
}

struct CorrelationWeek {
    let days: [CorrelationDay]       // 7 days, oldest first
    let patternNote: String
    let patternSources: [String]     // which metrics drove the pattern note
    let patternStrength: String      // "Strong", "Moderate"
}

// MARK: - Token Transactions

enum TokenTransactionType {
    case earned, spent, donated

    var sign: String {
        switch self {
        case .earned:  return "+"
        case .spent:   return "−"
        case .donated: return "−"
        }
    }

    var color: Color {
        switch self {
        case .earned:  return Color(hex: 0x3D7A5A)   // moss
        case .spent:   return Color(hex: 0x54627A)   // ink3
        case .donated: return Color(hex: 0x3D7A5A)   // moss — giving is positive
        }
    }

    var icon: String {
        switch self {
        case .earned:  return "arrow.down.circle"
        case .spent:   return "sparkles"
        case .donated: return "heart.circle"
        }
    }

    var label: String {
        switch self {
        case .earned:  return "Earned"
        case .spent:   return "Used"
        case .donated: return "Donated"
        }
    }
}

struct TokenTransaction: Identifiable {
    let id: UUID
    let date: Date
    let description: String
    let amount: Int
    let type: TokenTransactionType

    init(id: UUID = UUID(), date: Date, description: String,
         amount: Int, type: TokenTransactionType) {
        self.id          = id
        self.date        = date
        self.description = description
        self.amount      = amount
        self.type        = type
    }
}
