//
//  ScanDiff.swift
//  ReconKit
//
//  Compares two scans of the same target and summarizes what changed — the
//  core of monitoring. Surfaces grade movement, newly open/closed ports, new
//  or removed subdomains, and newly raised issues.
//

import Foundation

struct DiffChange: Identifiable, Hashable {
    enum Direction { case better, worse, neutral }
    var id = UUID()
    var text: String
    var direction: Direction
}

struct ScanDiff {
    var target: String
    var changes: [DiffChange]
    var hasChanges: Bool { !changes.isEmpty }

    static func between(old: ScanReport, new: ScanReport) -> ScanDiff {
        var changes: [DiffChange] = []

        // Score / grade movement.
        if new.score != old.score {
            let delta = new.score - old.score
            let dir: DiffChange.Direction = delta > 0 ? .better : .worse
            let arrow = delta > 0 ? "▲" : "▼"
            var text = "Security score \(arrow) \(old.score) → \(new.score)"
            if new.grade != old.grade { text += " (grade \(old.grade) → \(new.grade))" }
            changes.append(DiffChange(text: text, direction: dir))
        }

        // Per-category title sets: detect added/removed findings of note.
        changes += titleDiffs(category: .subdomains, old: old, new: new,
                              addedLabel: "New subdomain", removedLabel: "Subdomain gone",
                              filter: { $0.contains(".") })
        changes += titleDiffs(category: .ports, old: old, new: new,
                              addedLabel: "Port opened", removedLabel: "Port closed",
                              filter: { $0.lowercased().hasPrefix("port ") })

        // Newly raised warnings/criticals across the whole scan.
        let oldIssues = issueTitles(old)
        let newIssues = issueTitles(new)
        for title in newIssues.subtracting(oldIssues).sorted() {
            changes.append(DiffChange(text: "New issue: \(title)", direction: .worse))
        }
        for title in oldIssues.subtracting(newIssues).sorted() {
            changes.append(DiffChange(text: "Resolved: \(title)", direction: .better))
        }

        return ScanDiff(target: new.target, changes: changes)
    }

    private static func titleDiffs(category: ScanCategory, old: ScanReport, new: ScanReport,
                                   addedLabel: String, removedLabel: String,
                                   filter: (String) -> Bool) -> [DiffChange] {
        let oldSet = Set((old.result(for: category)?.findings ?? []).map(\.title).filter(filter))
        let newSet = Set((new.result(for: category)?.findings ?? []).map(\.title).filter(filter))
        var out: [DiffChange] = []
        for t in newSet.subtracting(oldSet).sorted() {
            out.append(DiffChange(text: "\(addedLabel): \(t)", direction: .worse))
        }
        for t in oldSet.subtracting(newSet).sorted() {
            out.append(DiffChange(text: "\(removedLabel): \(t)", direction: .neutral))
        }
        return out
    }

    private static func issueTitles(_ report: ScanReport) -> Set<String> {
        Set(report.results.flatMap(\.findings)
            .filter { $0.severity >= .warning }
            .map(\.title))
    }
}
