//
//  Models.swift
//  ReconKit
//
//  Core data types shared across the scan engine and UI.
//

import SwiftUI

/// Severity of a single finding. Drives color coding in the UI.
enum Severity: Int, Comparable, Codable {
    case pass = 0      // green  — secure / good
    case info = 1      // blue   — neutral fact
    case warning = 2   // yellow — worth a look
    case critical = 3  // red    — likely issue

    static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

    var color: Color {
        switch self {
        case .pass: return Theme.green
        case .info: return Theme.accentSoft
        case .warning: return Theme.gold
        case .critical: return Theme.danger
        }
    }

    var symbol: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    var label: String {
        switch self {
        case .pass: return "Pass"
        case .info: return "Info"
        case .warning: return "Warning"
        case .critical: return "Issue"
        }
    }
}

/// A single observation inside a category.
struct Finding: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var severity: Severity
    /// Optional plain-English fix, shown in the action plan and report.
    var remediation: String? = nil
}

/// The scan categories shown as tabs.
enum ScanCategory: String, CaseIterable, Codable, Identifiable {
    case overview = "Overview"
    case subdomains = "Subdomains"
    case dns = "DNS"
    case ssl = "SSL"
    case http = "HTTP"
    case ports = "Ports"
    case whois = "WHOIS"
    case reputation = "Reputation"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .subdomains: return "rectangle.3.group"
        case .dns: return "globe"
        case .ssl: return "lock.shield"
        case .http: return "network"
        case .ports: return "point.3.connected.trianglepath.dotted"
        case .whois: return "person.text.rectangle"
        case .reputation: return "shield.lefthalf.filled"
        }
    }
}

/// Findings for one category plus a one-line summary.
struct CategoryResult: Codable, Hashable {
    var category: ScanCategory
    var findings: [Finding]
    var summary: String

    /// Worst severity present, used for the category badge.
    var worst: Severity {
        findings.map(\.severity).max() ?? .info
    }
}

/// A complete scan of one target.
struct ScanReport: Identifiable, Codable, Hashable {
    var id = UUID()
    var target: String
    var date: Date
    var results: [CategoryResult]
    /// True for the built-in demo scan.
    var isSample: Bool = false

    func result(for category: ScanCategory) -> CategoryResult? {
        results.first { $0.category == category }
    }

    /// 0–100 security score derived from finding severities.
    var score: Int {
        var penalty = 0
        for f in results.flatMap(\.findings) {
            switch f.severity {
            case .critical: penalty += 18
            case .warning: penalty += 6
            default: break
            }
        }
        return max(0, min(100, 100 - penalty))
    }

    var rating: (label: String, color: Color) {
        switch score {
        case 85...100: return ("Strong", Theme.green)
        case 60..<85: return ("Fair", Theme.gold)
        default: return ("At Risk", Theme.danger)
        }
    }

    /// Letter grade derived from the score, like a security report card.
    var grade: String {
        switch score {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    /// Prioritized list of fixes: every warning/critical finding that has
    /// remediation advice, worst first.
    var actionPlan: [ActionItem] {
        var items: [ActionItem] = []
        for result in results where result.category != .overview {
            for finding in result.findings where finding.severity >= .warning {
                if let fix = RemediationEngine.advice(for: finding) {
                    items.append(ActionItem(category: result.category, finding: finding, fix: fix))
                }
            }
        }
        return items.sorted { $0.finding.severity > $1.finding.severity }
    }
}
