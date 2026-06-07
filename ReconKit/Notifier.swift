//
//  Notifier.swift
//  ReconKit
//
//  Local notifications for monitoring events: changes found on rescan and
//  certificates nearing expiry.
//

import Foundation
import UserNotifications

enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Fires alerts for a freshly completed scan: change summary and any
    /// soon-to-expire certificate.
    static func reportEvents(report: ScanReport, diff: ScanDiff?) {
        if let diff, diff.hasChanges {
            let worse = diff.changes.filter { $0.direction == .worse }
            let summary = (worse.isEmpty ? diff.changes : worse)
                .prefix(3).map(\.text).joined(separator: " · ")
            notify(title: "Changes on \(report.target)", body: summary)
        }
        // Cert expiry warning.
        if let expiry = report.result(for: .ssl)?.findings.first(where: { $0.title == "Expiry" }),
           expiry.severity >= .warning {
            notify(title: "Certificate expiring — \(report.target)", body: expiry.detail)
        }
    }
}
