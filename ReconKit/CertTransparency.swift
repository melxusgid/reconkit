//
//  CertTransparency.swift
//  ReconKit
//
//  Subdomain discovery via Certificate Transparency logs (crt.sh). Every
//  publicly-trusted TLS certificate is logged with its hostnames, so querying
//  CT logs reveals subdomains an attacker could enumerate. Free, no API key.
//

import Foundation

struct CTSubdomain: Hashable {
    var host: String
    var resolved: Bool
}

struct CertTransparencyScanner {
    /// Returns discovered subdomains for `domain`, marking which currently
    /// resolve to an address. Capped to keep scans responsive.
    func discover(domain: String, limit: Int = 60) async -> [CTSubdomain] {
        guard let names = await fetchNames(domain: domain) else { return [] }

        // Clean, dedupe, keep only hosts within the domain.
        var hosts = Set<String>()
        for raw in names {
            for line in raw.split(whereSeparator: \.isNewline) {
                var h = line.trimmingCharacters(in: .whitespaces).lowercased()
                if h.hasPrefix("*.") { h.removeFirst(2) }       // drop wildcard marker
                if h.isEmpty || h.contains(" ") { continue }
                if h == domain || h.hasSuffix("." + domain) { hosts.insert(h) }
            }
        }

        let sorted = hosts.sorted { lhs, rhs in
            // Shorter (closer to apex) first, then alphabetical.
            let lc = lhs.split(separator: ".").count, rc = rhs.split(separator: ".").count
            return lc == rc ? lhs < rhs : lc < rc
        }
        let capped = Array(sorted.prefix(limit))

        // Resolve concurrently to flag live hosts.
        let dns = DNSClient()
        let results: [CTSubdomain] = await withTaskGroup(of: CTSubdomain.self) { group in
            for host in capped {
                group.addTask {
                    let a = await dns.query(host, type: .a)
                    return CTSubdomain(host: host, resolved: !a.isEmpty)
                }
            }
            var out: [CTSubdomain] = []
            for await r in group { out.append(r) }
            return out
        }
        // Preserve the apex-first ordering.
        let order = Dictionary(uniqueKeysWithValues: capped.enumerated().map { ($1, $0) })
        return results.sorted { (order[$0.host] ?? 0) < (order[$1.host] ?? 0) }
    }

    /// Tries crt.sh first (unlimited but flaky); falls back to certspotter
    /// (reliable, lightly rate-limited) when crt.sh is unavailable.
    private func fetchNames(domain: String) async -> [String]? {
        if let names = await fetchCrtSh(domain: domain), !names.isEmpty { return names }
        return await fetchCertSpotter(domain: domain)
    }

    private func get(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("ReconKit/1.0", forHTTPHeaderField: "User-Agent")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func fetchCrtSh(domain: String) async -> [String]? {
        guard let data = await get("https://crt.sh/?q=%25.\(domain)&output=json"),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        return rows.compactMap { $0["name_value"] as? String }
    }

    private func fetchCertSpotter(domain: String) async -> [String]? {
        let url = "https://api.certspotter.com/v1/issuances?domain=\(domain)&include_subdomains=true&expand=dns_names"
        guard let data = await get(url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        // Each issuance has a dns_names array; flatten into newline-joined strings.
        return rows.compactMap { ($0["dns_names"] as? [String])?.joined(separator: "\n") }
    }
}
