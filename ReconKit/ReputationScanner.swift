//
//  ReputationScanner.swift
//  ReconKit
//
//  Real reputation signals from external sources:
//   • Have I Been Pwned — known breaches involving the domain (free, no key).
//   • URLhaus (abuse.ch) — malware URLs hosted on the domain (best-effort).
//   • VirusTotal — multi-vendor malware/blocklist verdicts (user's own key).
//

import Foundation

struct ReputationScanner {

    func scan(domain: String) async -> CategoryResult {
        async let breachesTask = haveIBeenPwned(domain: domain)
        async let urlhausTask = urlhaus(domain: domain)
        async let vtTask = virusTotal(domain: domain)

        var findings: [Finding] = []
        findings += await breachesTask
        findings += await urlhausTask
        findings += await vtTask

        // Always note HTTPS as a baseline trust signal handled elsewhere; here
        // summarize the worst.
        let worst = findings.map(\.severity).max() ?? .info
        let summary: String
        switch worst {
        case .critical: summary = "Flagged — see details"
        case .warning: summary = "Some reputation findings"
        default: summary = "No reputation issues found"
        }
        return CategoryResult(category: .reputation, findings: findings, summary: summary)
    }

    // MARK: - HTTP helper

    private func getJSON(_ urlString: String, headers: [String: String] = [:]) async -> Any? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("ReconKit/1.0 (macOS security scanner)", forHTTPHeaderField: "User-Agent")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    // MARK: - Have I Been Pwned (free breach list, no key)

    private func haveIBeenPwned(domain: String) async -> [Finding] {
        let url = "https://haveibeenpwned.com/api/v3/breaches?domain=\(domain)"
        guard let json = await getJSON(url) else {
            return [Finding(title: "Breach data unavailable",
                            detail: "Could not reach Have I Been Pwned.", severity: .info)]
        }
        guard let breaches = json as? [[String: Any]], !breaches.isEmpty else {
            return [Finding(title: "No known breaches",
                            detail: "No breaches involving this domain are recorded in Have I Been Pwned.",
                            severity: .pass)]
        }
        var findings: [Finding] = []
        let sorted = breaches.sorted { (($0["BreachDate"] as? String) ?? "") > (($1["BreachDate"] as? String) ?? "") }
        for b in sorted.prefix(8) {
            let name = (b["Title"] as? String) ?? (b["Name"] as? String) ?? "Breach"
            let date = (b["BreachDate"] as? String) ?? ""
            let year = date.split(separator: "-").first.map(String.init) ?? date
            let count = (b["PwnCount"] as? Int) ?? 0
            let classes = (b["DataClasses"] as? [String])?.prefix(5).joined(separator: ", ") ?? ""
            findings.append(Finding(
                title: "Breach: \(name) (\(year))",
                detail: "\(count.formatted()) accounts exposed. Compromised data: \(classes).",
                severity: .warning,
                remediation: "Force a password reset for affected users and require MFA. Verify no current credentials match those leaked."))
        }
        return findings
    }

    // MARK: - URLhaus (abuse.ch) — best-effort, skipped if unavailable

    private func urlhaus(domain: String) async -> [Finding] {
        guard let url = URL(string: "https://urlhaus-api.abuse.ch/v1/host/") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("ReconKit/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = "host=\(domain)".data(using: .utf8)
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["query_status"] as? String else {
            return []   // auth-required or down — stay silent
        }
        if status == "ok" {
            let count = (json["url_count"] as? String).flatMap { Int($0) }
                ?? (json["urls"] as? [[String: Any]])?.count ?? 0
            return [Finding(title: "Listed on URLhaus",
                            detail: "abuse.ch URLhaus has \(count) malware URL(s) recorded for this host.",
                            severity: .critical,
                            remediation: "Investigate immediately — the host may be compromised and serving malware. Clean it and request delisting.")]
        } else if status == "no_results" {
            return [Finding(title: "Clean on URLhaus",
                            detail: "No malware URLs recorded for this host on abuse.ch URLhaus.",
                            severity: .pass)]
        }
        return []
    }

    // MARK: - VirusTotal (user's own API key)

    private func virusTotal(domain: String) async -> [Finding] {
        guard let key = KeyStore.get(KeyStore.virusTotal) else {
            return [Finding(title: "VirusTotal not configured",
                            detail: "Add a free VirusTotal API key in Settings to scan this domain against 90+ security vendors and blocklists.",
                            severity: .info)]
        }
        let url = "https://www.virustotal.com/api/v3/domains/\(domain)"
        guard let json = await getJSON(url, headers: ["x-apikey": key]) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let attrs = data["attributes"] as? [String: Any] else {
            return [Finding(title: "VirusTotal lookup failed",
                            detail: "Could not retrieve a VirusTotal report (key invalid, rate-limited, or domain unknown).",
                            severity: .info)]
        }
        var findings: [Finding] = []
        if let stats = attrs["last_analysis_stats"] as? [String: Any] {
            let malicious = (stats["malicious"] as? Int) ?? 0
            let suspicious = (stats["suspicious"] as? Int) ?? 0
            let harmless = (stats["harmless"] as? Int) ?? 0
            let undetected = (stats["undetected"] as? Int) ?? 0
            let total = malicious + suspicious + harmless + undetected
            if malicious > 0 {
                findings.append(Finding(
                    title: "Flagged by \(malicious) vendor(s)",
                    detail: "\(malicious) malicious + \(suspicious) suspicious of \(total) VirusTotal engines flag this domain.",
                    severity: .critical,
                    remediation: "Review the VirusTotal report. If unexpected, the domain may be compromised or mis-categorized — request a re-scan/dispute."))
            } else if suspicious > 0 {
                findings.append(Finding(
                    title: "\(suspicious) vendor(s) suspicious",
                    detail: "\(suspicious) of \(total) VirusTotal engines mark this domain suspicious.",
                    severity: .warning))
            } else {
                findings.append(Finding(
                    title: "Clean on VirusTotal",
                    detail: "0 of \(total) security vendors flag this domain as malicious.",
                    severity: .pass))
            }
        }
        if let rep = attrs["reputation"] as? Int {
            findings.append(Finding(title: "VirusTotal reputation score",
                                    detail: "\(rep) (community-driven; higher is better).",
                                    severity: rep < 0 ? .warning : .info))
        }
        if let cats = attrs["categories"] as? [String: String], !cats.isEmpty {
            let values = Array(Set(cats.values))
            let lower = values.joined(separator: " ").lowercased()
            let badWords = ["malicious", "malware", "phishing", "spam", "scam", "fraud", "suspicious", "spyware", "botnet"]
            let flagged = badWords.contains { lower.contains($0) }
            findings.append(Finding(
                title: flagged ? "Flagged category" : "Category",
                detail: values.prefix(6).joined(separator: ", "),
                severity: flagged ? .warning : .info,
                remediation: flagged
                    ? "VirusTotal partners categorize this domain as malicious/unwanted. If this is your domain, it may be compromised or mis-categorized — investigate and request a category review."
                    : nil))
        }
        return findings
    }
}
