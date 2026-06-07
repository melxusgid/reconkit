//
//  SampleData.swift
//  ReconKit
//
//  A canned scan so users (and the App Store reviewer) can see a full report
//  without hitting the network.
//

import Foundation

enum SampleData {
    static func demoReport() -> ScanReport {
        let dns = CategoryResult(category: .dns, findings: [
            Finding(title: "A record", detail: "93.184.216.34", severity: .info),
            Finding(title: "AAAA record", detail: "2606:2800:220:1:248:1893:25c8:1946", severity: .info),
            Finding(title: "Nameserver", detail: "a.iana-servers.net", severity: .info),
            Finding(title: "Nameserver", detail: "b.iana-servers.net", severity: .info),
            Finding(title: "Mail server (MX)", detail: "0 .", severity: .info),
            Finding(title: "SPF present", detail: "An SPF policy was found in TXT records.", severity: .pass),
            Finding(title: "No DMARC record", detail: "No DMARC policy found; receivers can't tell how to handle spoofed mail.", severity: .warning),
            Finding(title: "DNSSEC enabled", detail: "Zone is signed (2 DNSKEY records).", severity: .pass),
            Finding(title: "No CAA record", detail: "Any certificate authority can issue a cert for this domain.", severity: .warning),
        ], summary: "2 address records, 2 NS, 1 MX")

        let subdomains = CategoryResult(category: .subdomains, findings: [
            Finding(title: "7 subdomains in CT logs", detail: "5 currently resolve. Discovered from publicly-logged TLS certificates (crt.sh).", severity: .info),
            Finding(title: "www.example.com", detail: "Resolves — live host.", severity: .info),
            Finding(title: "api.example.com", detail: "Resolves — live host.", severity: .info),
            Finding(title: "mail.example.com", detail: "Resolves — live host.", severity: .info),
            Finding(title: "dev.example.com", detail: "Resolves — live host.", severity: .info),
            Finding(title: "staging.example.com", detail: "Resolves — live host.", severity: .info),
            Finding(title: "old.example.com", detail: "In CT logs but does not currently resolve.", severity: .pass),
            Finding(title: "vpn.example.com", detail: "In CT logs but does not currently resolve.", severity: .pass),
        ], summary: "7 found, 5 live")

        let ssl = CategoryResult(category: .ssl, findings: [
            Finding(title: "Subject", detail: "example.com", severity: .info),
            Finding(title: "Issuer", detail: "DigiCert Inc", severity: .info),
            Finding(title: "Valid from", detail: "Jan 30, 2026", severity: .info),
            Finding(title: "Valid until", detail: "Mar 1, 2027", severity: .info),
            Finding(title: "Expiry", detail: "Certificate valid for 270 more day(s).", severity: .pass),
            Finding(title: "TLS 1.3 supported", detail: "The server accepts the latest, most secure TLS version.", severity: .pass),
            Finding(title: "TLS 1.2 supported", detail: "Modern, secure TLS version accepted.", severity: .pass),
        ], summary: "Valid (270d left)")

        let http = CategoryResult(category: .http, findings: [
            Finding(title: "Status 200", detail: "Final URL: https://example.com/", severity: .pass),
            Finding(title: "Server", detail: "ECS (sec/96EE)", severity: .info),
            Finding(title: "HSTS set", detail: "max-age=63072000", severity: .pass),
            Finding(title: "Missing Content Security Policy", detail: "CSP limits which sources can load scripts/styles, mitigating XSS.", severity: .warning),
            Finding(title: "X-Content-Type-Options set", detail: "nosniff", severity: .pass),
            Finding(title: "Tech stack", detail: "ECS, Cloudflare", severity: .info),
        ], summary: "HTTP 200, 1 security header missing")

        let ports = CategoryResult(category: .ports, findings: [
            Finding(title: "Port 80 open (HTTP)", detail: "TCP handshake succeeded.", severity: .info),
            Finding(title: "Port 443 open (HTTPS)", detail: "TCP handshake succeeded.", severity: .info),
        ], summary: "2 of 15 common ports open")

        let whois = CategoryResult(category: .whois, findings: [
            Finding(title: "Registrar", detail: "RESERVED-Internet Assigned Numbers Authority", severity: .info),
            Finding(title: "Created", detail: "1995-08-14", severity: .info),
            Finding(title: "Expires", detail: "2026-08-13", severity: .info),
            Finding(title: "Status", detail: "clientDeleteProhibited", severity: .info),
        ], summary: "Expires 2026-08-13")

        let reputation = CategoryResult(category: .reputation, findings: [
            Finding(title: "No known breaches", detail: "No breaches involving this domain are recorded in Have I Been Pwned.", severity: .pass),
            Finding(title: "Clean on URLhaus", detail: "No malware URLs recorded for this host on abuse.ch URLhaus.", severity: .pass),
            Finding(title: "Clean on VirusTotal", detail: "0 of 94 security vendors flag this domain as malicious.", severity: .pass),
            Finding(title: "Category", detail: "information technology", severity: .info),
        ], summary: "No reputation issues found")

        let overview = CategoryResult(category: .overview, findings: [
            Finding(title: "Target", detail: "example.com", severity: .info),
            Finding(title: "Reachable", detail: "Responded with HTTP 200.", severity: .pass),
            Finding(title: "DNS: No DMARC record", detail: "No DMARC policy found.", severity: .warning),
            Finding(title: "HTTP: Missing Content Security Policy", detail: "CSP limits which sources can load scripts/styles.", severity: .warning),
        ], summary: "Scan complete")

        return ScanReport(
            target: "example.com (demo)",
            date: Date(),
            results: [overview, subdomains, dns, ssl, http, ports, whois, reputation],
            isSample: true
        )
    }
}
