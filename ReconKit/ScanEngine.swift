//
//  ScanEngine.swift
//  ReconKit
//
//  Orchestrates the individual probes into a full ScanReport, reporting each
//  category as it finishes so the UI can fill in progressively.
//

import Foundation

actor ScanEngine {

    /// Runs every category for `target`. Calls `onCategory` on completion of
    /// each so the UI can stream results in.
    func scan(target raw: String, onCategory: @Sendable @escaping (CategoryResult) -> Void) async -> ScanReport {
        let host = Self.hostComponent(from: raw)
        var collected: [CategoryResult] = []

        func emit(_ result: CategoryResult) {
            collected.append(result)
            onCategory(result)
        }

        // DNS first — other categories want the resolved address.
        let dns = await scanDNS(host: host)
        emit(dns)

        // Subdomain discovery (CT logs) runs in the background while the rest
        // of the scan proceeds.
        async let subdomainsTask = scanSubdomains(host: host)

        // HTTP + SSL share one request. A second plain-HTTP request checks
        // whether the site upgrades insecure connections to HTTPS.
        let http = HTTPProbe()
        async let httpsUpgradeTask = Self.checksHTTPSUpgrade(host: host)
        let httpResult = await http.fetch(urlString: host)
        let upgrade = await httpsUpgradeTask
        emit(scanHTTP(host: host, result: httpResult, httpsUpgrade: upgrade))
        emit(await scanSSL(host: host, result: httpResult))

        emit(await scanPorts(host: host))
        emit(await subdomainsTask)
        emit(await scanWHOIS(host: host))
        emit(await scanReputation(host: host))

        // Overview synthesized from the rest.
        let overview = scanOverview(host: host, results: collected, http: httpResult)
        collected.insert(overview, at: 0)
        onCategory(overview)

        return ScanReport(target: host, date: Date(), results: orderedResults(collected))
    }

    // MARK: - Host parsing

    static func hostComponent(from raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = s.range(of: "://") { s = String(s[range.upperBound...]) }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        if let colon = s.firstIndex(of: ":") { s = String(s[..<colon]) }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    private func orderedResults(_ results: [CategoryResult]) -> [CategoryResult] {
        ScanCategory.allCases.compactMap { cat in results.first { $0.category == cat } }
    }

    // MARK: - DNS

    private func scanDNS(host: String) async -> CategoryResult {
        let client = DNSClient()
        async let a = client.query(host, type: .a)
        async let aaaa = client.query(host, type: .aaaa)
        async let mx = client.query(host, type: .mx)
        async let ns = client.query(host, type: .ns)
        async let txt = client.query(host, type: .txt)
        async let soa = client.query(host, type: .soa)
        async let caa = client.query(host, type: .caa)
        async let dnskey = client.query(host, type: .dnskey)

        let (aRecs, aaaaRecs, mxRecs, nsRecs, txtRecs, soaRecs, caaRecs, dnskeyRecs) =
            await (a, aaaa, mx, ns, txt, soa, caa, dnskey)

        var findings: [Finding] = []

        if aRecs.isEmpty && aaaaRecs.isEmpty {
            findings.append(Finding(title: "No A/AAAA records",
                                    detail: "The host did not resolve to an IPv4 or IPv6 address. It may not exist or DNS is unreachable.",
                                    severity: .critical))
        } else {
            for r in aRecs {
                findings.append(Finding(title: "A record", detail: r.value, severity: .info))
            }
            for r in aaaaRecs {
                findings.append(Finding(title: "AAAA record", detail: r.value, severity: .info))
            }
        }

        for r in nsRecs {
            findings.append(Finding(title: "Nameserver", detail: r.value, severity: .info))
        }
        if !nsRecs.isEmpty && nsRecs.count < 2 {
            findings.append(Finding(title: "Single nameserver",
                                    detail: "Only one nameserver found. RFC best practice is at least two on diverse networks for redundancy.",
                                    severity: .warning))
        }
        for r in mxRecs {
            findings.append(Finding(title: "Mail server (MX)", detail: r.value, severity: .info))
        }

        var hasSPF = false, hasDMARC = false
        for r in txtRecs {
            let v = r.value
            if v.lowercased().hasPrefix("v=spf1") { hasSPF = true }
            findings.append(Finding(title: "TXT record", detail: v, severity: .info))
        }
        // DMARC lives on a subdomain.
        let dmarc = await client.query("_dmarc.\(host)", type: .txt)
        if dmarc.contains(where: { $0.value.lowercased().contains("v=dmarc1") }) { hasDMARC = true }

        if !mxRecs.isEmpty {
            findings.append(Finding(title: hasSPF ? "SPF present" : "No SPF record",
                                    detail: hasSPF ? "An SPF policy was found in TXT records." : "Domain accepts mail but has no SPF record; spoofing protection is weaker.",
                                    severity: hasSPF ? .pass : .warning))
            findings.append(Finding(title: hasDMARC ? "DMARC present" : "No DMARC record",
                                    detail: hasDMARC ? "A DMARC policy was found at _dmarc." : "No DMARC policy found; receivers can't tell how to handle spoofed mail.",
                                    severity: hasDMARC ? .pass : .warning))
        }

        if let soaRec = soaRecs.first {
            findings.append(Finding(title: "SOA", detail: soaRec.value, severity: .info))
        }

        // DNSSEC — signed zones return DNSKEY records.
        if !(aRecs.isEmpty && aaaaRecs.isEmpty) {
            if dnskeyRecs.isEmpty {
                findings.append(Finding(title: "DNSSEC not enabled",
                                        detail: "No DNSKEY records found. DNSSEC signs DNS responses so resolvers can detect tampering/spoofing.",
                                        severity: .warning))
            } else {
                findings.append(Finding(title: "DNSSEC enabled",
                                        detail: "Zone is signed (\(dnskeyRecs.count) DNSKEY record(s)).",
                                        severity: .pass))
            }
        }

        // CAA — restricts which CAs may issue certs for the domain.
        if caaRecs.isEmpty {
            findings.append(Finding(title: "No CAA record",
                                    detail: "Any certificate authority can issue a cert for this domain. A CAA record restricts issuance to CAs you trust.",
                                    severity: .warning))
        } else {
            for r in caaRecs {
                findings.append(Finding(title: "CAA record", detail: r.value, severity: .pass))
            }
        }

        let summary: String
        if aRecs.isEmpty && aaaaRecs.isEmpty {
            summary = "Did not resolve"
        } else {
            summary = "\(aRecs.count + aaaaRecs.count) address record(s), \(nsRecs.count) NS, \(mxRecs.count) MX"
        }
        return CategoryResult(category: .dns, findings: findings, summary: summary)
    }

    // MARK: - Subdomains (attack surface via Certificate Transparency)

    private func scanSubdomains(host: String) async -> CategoryResult {
        let domain = Self.registrableDomain(from: host)
        let found = await CertTransparencyScanner().discover(domain: domain)

        guard !found.isEmpty else {
            return CategoryResult(category: .subdomains, findings: [
                Finding(title: "No subdomains discovered",
                        detail: "Certificate Transparency logs returned no hostnames for \(domain), or crt.sh was unreachable.",
                        severity: .info)
            ], summary: "No data")
        }

        let live = found.filter(\.resolved)
        var findings: [Finding] = []
        // Informational: a large attack surface is worth reviewing but isn't a
        // misconfiguration, so it doesn't lower the security score.
        findings.append(Finding(title: "\(found.count) subdomains in CT logs",
                                detail: "\(live.count) currently resolve. Each is part of the domain's public attack surface. Discovered from publicly-logged TLS certificates (crt.sh). Review for stale or forgotten hosts.",
                                severity: .info))
        for sub in found {
            findings.append(Finding(title: sub.host,
                                    detail: sub.resolved ? "Resolves — live host." : "In CT logs but does not currently resolve.",
                                    severity: sub.resolved ? .info : .pass))
        }
        return CategoryResult(category: .subdomains, findings: findings,
                              summary: "\(found.count) found, \(live.count) live")
    }

    // MARK: - HTTP

    /// Checks whether http://host upgrades to https:// (forced HTTPS).
    static func checksHTTPSUpgrade(host: String) async -> Bool? {
        let probe = HTTPProbe()
        guard let result = await probe.fetch(urlString: "http://" + host, timeout: 8) else { return nil }
        return result.finalURL.scheme?.lowercased() == "https"
    }

    private func scanHTTP(host: String, result: HTTPResult?, httpsUpgrade: Bool?) -> CategoryResult {
        guard let result else {
            return CategoryResult(category: .http,
                                  findings: [Finding(title: "No HTTP response",
                                                     detail: "Could not complete an HTTPS request to the host.",
                                                     severity: .critical)],
                                  summary: "Unreachable")
        }
        var findings: [Finding] = []
        if let httpsUpgrade {
            findings.append(Finding(
                title: httpsUpgrade ? "HTTP upgrades to HTTPS" : "HTTP not redirected to HTTPS",
                detail: httpsUpgrade
                    ? "Plain http:// requests are redirected to https://."
                    : "Plain http:// did not redirect to https://. Visitors can be served insecurely; force a redirect to HTTPS.",
                severity: httpsUpgrade ? .pass : .warning))
        }
        findings.append(Finding(title: "Status \(result.statusCode)",
                                detail: "Final URL: \(result.finalURL.absoluteString)",
                                severity: (200..<400).contains(result.statusCode) ? .pass : .warning))

        if !result.redirectChain.isEmpty {
            findings.append(Finding(title: "Redirect chain",
                                    detail: (result.redirectChain + [result.finalURL.absoluteString]).joined(separator: " → "),
                                    severity: .info))
        }

        if let server = result.serverHeader {
            findings.append(Finding(title: "Server", detail: server, severity: .info))
        }

        // Security headers.
        let checks: [(name: String, header: String, advice: String)] = [
            ("HSTS", "strict-transport-security", "Strict-Transport-Security forces HTTPS and blocks downgrade attacks."),
            ("Content Security Policy", "content-security-policy", "CSP limits which sources can load scripts/styles, mitigating XSS."),
            ("X-Frame-Options", "x-frame-options", "X-Frame-Options (or CSP frame-ancestors) blocks clickjacking."),
            ("X-Content-Type-Options", "x-content-type-options", "Set to nosniff to stop MIME-type sniffing."),
            ("Referrer-Policy", "referrer-policy", "Referrer-Policy controls how much referrer data leaks to other sites."),
            ("Permissions-Policy", "permissions-policy", "Permissions-Policy restricts powerful browser features (camera, geolocation, etc.)."),
        ]
        let lowerHeaders = Dictionary(uniqueKeysWithValues: result.headers.map { ($0.key.lowercased(), $0.value) })
        for c in checks {
            if let value = lowerHeaders[c.header] {
                findings.append(Finding(title: "\(c.name) set", detail: value, severity: .pass))
            } else {
                findings.append(Finding(title: "Missing \(c.name)", detail: c.advice, severity: .warning))
            }
        }

        // HSTS detail: includeSubDomains / preload.
        if let hsts = lowerHeaders["strict-transport-security"]?.lowercased() {
            if !hsts.contains("includesubdomains") {
                findings.append(Finding(title: "HSTS without includeSubDomains",
                                        detail: "HSTS is set but doesn't cover subdomains. Add `includeSubDomains` (and `preload`) for full protection.",
                                        severity: .warning))
            }
        }

        // Cookie security flags.
        if let cookie = lowerHeaders["set-cookie"] {
            let c = cookie.lowercased()
            if !c.contains("secure") {
                findings.append(Finding(title: "Cookie missing Secure flag",
                                        detail: "A Set-Cookie response lacks the Secure attribute, so cookies can be sent over plain HTTP.",
                                        severity: .warning))
            }
            if !c.contains("httponly") {
                findings.append(Finding(title: "Cookie missing HttpOnly flag",
                                        detail: "A cookie lacks HttpOnly, leaving it readable by JavaScript (XSS theft risk).",
                                        severity: .warning))
            }
            if !c.contains("samesite") {
                findings.append(Finding(title: "Cookie missing SameSite",
                                        detail: "No SameSite attribute; set SameSite=Lax or Strict to reduce CSRF exposure.",
                                        severity: .info))
            }
        }

        // Tech fingerprints.
        var tech: [String] = []
        if let powered = lowerHeaders["x-powered-by"] { tech.append(powered) }
        if let server = result.serverHeader { tech.append(server) }
        if lowerHeaders["x-shopify-stage"] != nil { tech.append("Shopify") }
        if lowerHeaders["x-drupal-cache"] != nil { tech.append("Drupal") }
        if (lowerHeaders["set-cookie"] ?? "").lowercased().contains("wordpress") { tech.append("WordPress") }
        if let cf = lowerHeaders["cf-ray"], !cf.isEmpty { tech.append("Cloudflare") }
        if !tech.isEmpty {
            findings.append(Finding(title: "Tech stack",
                                    detail: Array(Set(tech)).joined(separator: ", "),
                                    severity: .info))
        }

        let missing = checks.filter { lowerHeaders[$0.header] == nil }.count
        let summary = "HTTP \(result.statusCode), \(missing) security header(s) missing"
        return CategoryResult(category: .http, findings: findings, summary: summary)
    }

    // MARK: - SSL

    private func scanSSL(host: String, result: HTTPResult?) async -> CategoryResult {
        guard let cert = result?.cert else {
            return CategoryResult(category: .ssl,
                                  findings: [Finding(title: "No certificate observed",
                                                     detail: "Could not retrieve a TLS certificate. The host may not serve HTTPS.",
                                                     severity: .critical)],
                                  summary: "No HTTPS")
        }
        var findings: [Finding] = []
        if let cn = cert.commonName {
            findings.append(Finding(title: "Subject", detail: cn, severity: .info))
        }
        if let issuer = cert.issuer {
            findings.append(Finding(title: "Issuer", detail: issuer, severity: .info))
        }
        let df = DateFormatter()
        df.dateStyle = .medium
        if let nb = cert.notBefore {
            findings.append(Finding(title: "Valid from", detail: df.string(from: nb), severity: .info))
        }
        if let na = cert.notAfter {
            findings.append(Finding(title: "Valid until", detail: df.string(from: na), severity: .info))
        }
        if cert.chainLength > 0 {
            let complete = cert.chainLength >= 2
            findings.append(Finding(title: "Certificate chain",
                                    detail: "\(cert.chainLength) certificate(s) in chain\(complete ? " (leaf + intermediate/root)." : " — chain may be incomplete.")",
                                    severity: complete ? .pass : .warning))
        }
        if !cert.sans.isEmpty {
            let shown = cert.sans.prefix(12).joined(separator: ", ")
            let extra = cert.sans.count > 12 ? " (+\(cert.sans.count - 12) more)" : ""
            findings.append(Finding(title: "Covers \(cert.sans.count) hostname(s)",
                                    detail: shown + extra,
                                    severity: .info))
        }

        var summary = "Valid certificate"
        if let days = cert.daysUntilExpiry {
            let sev: Severity = days < 0 ? .critical : (days < 21 ? .warning : .pass)
            let text: String
            if days < 0 { text = "Certificate expired \(-days) day(s) ago."; summary = "Expired" }
            else if days < 21 { text = "Certificate expires in \(days) day(s) — renew soon."; summary = "Expires in \(days)d" }
            else { text = "Certificate valid for \(days) more day(s)."; summary = "Valid (\(days)d left)" }
            findings.append(Finding(title: "Expiry", detail: text, severity: sev))
        }

        // Report the TLS version the server actually negotiates.
        if let ver = await TLSProbe.negotiatedVersion(host: host) {
            let legacy = (ver == "1.0" || ver == "1.1")
            findings.append(Finding(
                title: "Negotiated TLS \(ver)",
                detail: legacy
                    ? "Server negotiated deprecated TLS \(ver), which has known weaknesses. Upgrade to TLS 1.2 or 1.3."
                    : "Server negotiated a modern, secure TLS version.",
                severity: legacy ? .critical : .pass))
            if legacy { summary += " · legacy TLS" }
        }

        return CategoryResult(category: .ssl, findings: findings, summary: summary)
    }

    // MARK: - Ports

    private func scanPorts(host: String) async -> CategoryResult {
        let common: [(port: UInt16, name: String)] = [
            (21, "FTP"), (22, "SSH"), (25, "SMTP"), (53, "DNS"),
            (80, "HTTP"), (110, "POP3"), (143, "IMAP"), (443, "HTTPS"),
            (3306, "MySQL"), (3389, "RDP"), (5432, "PostgreSQL"),
            (6379, "Redis"), (8080, "HTTP-alt"), (8443, "HTTPS-alt"), (27017, "MongoDB"),
        ]

        // Ports where the service greets first, so a banner can be read.
        let bannerPorts: Set<UInt16> = [21, 22, 25, 110, 143]

        // Probe concurrently, grabbing a banner where the protocol allows.
        let results: [(UInt16, String, Bool, String?)] = await withTaskGroup(of: (UInt16, String, Bool, String?).self) { group in
            for c in common {
                group.addTask {
                    let open = await TCPProbe.isOpen(host: host, port: c.port)
                    var banner: String? = nil
                    if open && bannerPorts.contains(c.port) {
                        banner = await BannerGrabber.grab(host: host, port: c.port)
                    }
                    return (c.port, c.name, open, banner)
                }
            }
            var out: [(UInt16, String, Bool, String?)] = []
            for await r in group { out.append(r) }
            return out
        }

        let sorted = results.sorted { $0.0 < $1.0 }
        var findings: [Finding] = []
        var openCount = 0
        // Ports that are risky when publicly reachable.
        let sensitive: Set<UInt16> = [21, 23, 3306, 3389, 5432, 6379, 27017]
        for (port, name, open, banner) in sorted where open {
            openCount += 1
            let sev: Severity = sensitive.contains(port) ? .warning : .info
            let note = sensitive.contains(port) ? " — exposing this publicly is risky" : ""
            var detail = "TCP handshake succeeded\(note)."
            if let banner { detail += "\nBanner: \(banner)" }
            findings.append(Finding(title: "Port \(port) open (\(name))",
                                    detail: detail,
                                    severity: sev))
        }
        if findings.isEmpty {
            findings.append(Finding(title: "No common ports open",
                                    detail: "None of the \(common.count) probed common ports accepted a TCP connection (firewall or filtered).",
                                    severity: .pass))
        }
        return CategoryResult(category: .ports, findings: findings,
                              summary: "\(openCount) of \(common.count) common ports open")
    }

    // MARK: - WHOIS

    private func scanWHOIS(host: String) async -> CategoryResult {
        let domain = Self.registrableDomain(from: host)
        guard let text = await WHOISClient().lookup(domain: domain) else {
            return CategoryResult(category: .whois,
                                  findings: [Finding(title: "WHOIS unavailable",
                                                     detail: "No response from WHOIS servers for \(domain).",
                                                     severity: .info)],
                                  summary: "No data")
        }
        var findings: [Finding] = []
        func add(_ title: String, _ keys: [String], severity: Severity = .info) -> String? {
            if let v = WHOISClient.value(for: keys, in: text) {
                findings.append(Finding(title: title, detail: v, severity: severity))
                return v
            }
            return nil
        }
        _ = add("Registrar", ["Registrar", "registrar"])
        let created = add("Created", ["Creation Date", "created", "Registered On"])
        // Domain age — older domains are generally more trustworthy.
        if let created, let age = Self.yearsSince(created) {
            findings.append(Finding(title: "Domain age",
                                    detail: String(format: "Registered ~%.1f years ago.", age),
                                    severity: age < 0.25 ? .warning : .info))
        }
        _ = add("Updated", ["Updated Date", "last-update", "Last Modified"])
        let expiry = add("Expires", ["Registry Expiry Date", "Registrar Registration Expiration Date", "Expiry Date", "paid-till"])
        if let statuses = WHOISClient.value(for: ["Domain Status", "status"], in: text) {
            findings.append(Finding(title: "Status", detail: statuses, severity: .info))
        }

        if findings.isEmpty {
            findings.append(Finding(title: "Raw WHOIS",
                                    detail: String(text.prefix(800)),
                                    severity: .info))
        }

        var summary = "Registered domain"
        if let expiry { summary = "Expires \(expiry.prefix(10))" }
        else if let created { summary = "Created \(created.prefix(10))" }
        return CategoryResult(category: .whois, findings: findings, summary: summary)
    }

    /// Parses a WHOIS date (ISO 8601 or yyyy-MM-dd) and returns years elapsed.
    static func yearsSince(_ dateString: String) -> Double? {
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)
        var date: Date?
        let iso = ISO8601DateFormatter()
        date = iso.date(from: trimmed)
        if date == nil {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            for fmt in ["yyyy-MM-dd", "yyyy.MM.dd", "dd-MMM-yyyy"] {
                df.dateFormat = fmt
                if let d = df.date(from: String(trimmed.prefix(11))) { date = d; break }
            }
        }
        guard let date else { return nil }
        return -date.timeIntervalSinceNow / (365.25 * 86400)
    }

    /// Naive registrable-domain extraction (last two labels). Good enough for
    /// most TLDs in v1; multi-part TLDs (e.g. co.uk) fall back gracefully.
    static func registrableDomain(from host: String) -> String {
        let parts = host.split(separator: ".")
        guard parts.count > 2 else { return host }
        return parts.suffix(2).joined(separator: ".")
    }

    // MARK: - Reputation (live: HIBP breaches, URLhaus, VirusTotal)

    private func scanReputation(host: String) async -> CategoryResult {
        let domain = Self.registrableDomain(from: host)
        return await ReputationScanner().scan(domain: domain)
    }

    // MARK: - Overview

    private func scanOverview(host: String, results: [CategoryResult], http: HTTPResult?) -> CategoryResult {
        var findings: [Finding] = []
        findings.append(Finding(title: "Target", detail: host, severity: .info))
        if let http {
            findings.append(Finding(title: "Reachable",
                                    detail: "Responded with HTTP \(http.statusCode).",
                                    severity: .pass))
        }
        // Surface the worst finding from each category.
        for r in results {
            let worst = r.findings.max { $0.severity < $1.severity }
            if let worst, worst.severity >= .warning {
                findings.append(Finding(title: "\(r.category.rawValue): \(worst.title)",
                                        detail: worst.detail,
                                        severity: worst.severity))
            }
        }
        if findings.count <= 2 {
            findings.append(Finding(title: "No major issues",
                                    detail: "No warnings or critical findings were raised across the scanned categories.",
                                    severity: .pass))
        }
        return CategoryResult(category: .overview, findings: findings, summary: "Scan complete")
    }
}
