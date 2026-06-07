//
//  SampleData.swift
//  ReconKit
//
//  A canned scan so users can see a full report without hitting the network.
//  Captured from a real scan of example.com so the demo matches what a live
//  scan actually returns. Regenerate by snapshotting a real ScanReport.
//

import Foundation

enum SampleData {
    static func demoReport() -> ScanReport {
        let overview = CategoryResult(category: .overview, findings: [
            Finding(title: "Target", detail: "example.com", severity: .info),
            Finding(title: "Reachable", detail: "Responded with HTTP 200.", severity: .pass),
            Finding(title: "DNS: No CAA record", detail: "Any certificate authority can issue a cert for this domain. A CAA record restricts issuance to CAs you trust.", severity: .warning),
            Finding(title: "HTTP: Missing HSTS", detail: "Strict-Transport-Security forces HTTPS and blocks downgrade attacks.", severity: .warning),
        ], summary: "Scan complete")

        let subdomains = CategoryResult(category: .subdomains, findings: [
            Finding(title: "2 subdomains in CT logs", detail: "2 currently resolve. Each is part of the domain's public attack surface. Discovered from publicly-logged TLS certificates (crt.sh). Review for stale or forgotten hosts.", severity: .info),
            Finding(title: "example.com", detail: "Resolves — live host.", severity: .info),
            Finding(title: "www.example.com", detail: "Resolves — live host.", severity: .info),
        ], summary: "2 found, 2 live")

        let dns = CategoryResult(category: .dns, findings: [
            Finding(title: "A record", detail: "104.20.23.154", severity: .info),
            Finding(title: "A record", detail: "172.66.147.243", severity: .info),
            Finding(title: "AAAA record", detail: "2606:4700:10:0:0:0:6814:179a", severity: .info),
            Finding(title: "AAAA record", detail: "2606:4700:10:0:0:0:ac42:93f3", severity: .info),
            Finding(title: "Nameserver", detail: "hera.ns.cloudflare.com", severity: .info),
            Finding(title: "Nameserver", detail: "elliott.ns.cloudflare.com", severity: .info),
            Finding(title: "Mail server (MX)", detail: "0 ", severity: .info),
            Finding(title: "TXT record", detail: "v=spf1 -all", severity: .info),
            Finding(title: "TXT record", detail: "_k2n1y4vw3qtb4skdx9e7dxt97qrmmq9", severity: .info),
            Finding(title: "SPF present", detail: "An SPF policy was found in TXT records.", severity: .pass),
            Finding(title: "DMARC present", detail: "A DMARC policy was found at _dmarc.", severity: .pass),
            Finding(title: "SOA", detail: "elliott.ns.cloudflare.com dns.cloudflare.com", severity: .info),
            Finding(title: "DNSSEC enabled", detail: "Zone is signed (4 DNSKEY record(s)).", severity: .pass),
            Finding(title: "No CAA record", detail: "Any certificate authority can issue a cert for this domain. A CAA record restricts issuance to CAs you trust.", severity: .warning),
        ], summary: "4 address record(s), 2 NS, 1 MX")

        let ssl = CategoryResult(category: .ssl, findings: [
            Finding(title: "Subject", detail: "example.com", severity: .info),
            Finding(title: "Issuer", detail: "SSL Corporation", severity: .info),
            Finding(title: "Valid from", detail: "May 31, 2026", severity: .info),
            Finding(title: "Valid until", detail: "Aug 29, 2026", severity: .info),
            Finding(title: "Certificate chain", detail: "4 certificate(s) in chain (leaf + intermediate/root).", severity: .pass),
            Finding(title: "Covers 2 hostname(s)", detail: "example.com, *.example.com", severity: .info),
            Finding(title: "Expiry", detail: "Certificate valid for 82 more day(s).", severity: .pass),
            Finding(title: "Negotiated TLS 1.3", detail: "Server negotiated a modern, secure TLS version.", severity: .pass),
        ], summary: "Valid (82d left)")

        let http = CategoryResult(category: .http, findings: [
            Finding(title: "Status 200", detail: "Final URL: https://example.com/", severity: .pass),
            Finding(title: "Server", detail: "cloudflare", severity: .info),
            Finding(title: "Missing HSTS", detail: "Strict-Transport-Security forces HTTPS and blocks downgrade attacks.", severity: .warning),
            Finding(title: "Missing Content Security Policy", detail: "CSP limits which sources can load scripts/styles, mitigating XSS.", severity: .warning),
            Finding(title: "Missing X-Frame-Options", detail: "X-Frame-Options (or CSP frame-ancestors) blocks clickjacking.", severity: .warning),
            Finding(title: "Missing X-Content-Type-Options", detail: "Set to nosniff to stop MIME-type sniffing.", severity: .warning),
            Finding(title: "Missing Referrer-Policy", detail: "Referrer-Policy controls how much referrer data leaks to other sites.", severity: .warning),
            Finding(title: "Missing Permissions-Policy", detail: "Permissions-Policy restricts powerful browser features (camera, geolocation, etc.).", severity: .warning),
            Finding(title: "Tech stack", detail: "cloudflare, Cloudflare", severity: .info),
        ], summary: "HTTP 200, 6 security header(s) missing")

        let ports = CategoryResult(category: .ports, findings: [
            Finding(title: "Port 80 open (HTTP)", detail: "TCP handshake succeeded.", severity: .info),
            Finding(title: "Port 443 open (HTTPS)", detail: "TCP handshake succeeded.", severity: .info),
            Finding(title: "Port 8080 open (HTTP-alt)", detail: "TCP handshake succeeded.", severity: .info),
            Finding(title: "Port 8443 open (HTTPS-alt)", detail: "TCP handshake succeeded.", severity: .info),
        ], summary: "4 of 15 common ports open")

        let whois = CategoryResult(category: .whois, findings: [
            Finding(title: "Registrar", detail: "RESERVED-Internet Assigned Numbers Authority", severity: .info),
            Finding(title: "Created", detail: "1995-08-14T04:00:00Z", severity: .info),
            Finding(title: "Domain age", detail: "Registered ~30.8 years ago.", severity: .info),
            Finding(title: "Updated", detail: "2026-01-16T18:26:50Z", severity: .info),
            Finding(title: "Expires", detail: "2026-08-13T04:00:00Z", severity: .info),
            Finding(title: "Status", detail: "clientDeleteProhibited https://icann.org/epp#clientDeleteProhibited", severity: .info),
        ], summary: "Expires 2026-08-13")

        let reputation = CategoryResult(category: .reputation, findings: [
            Finding(title: "No known breaches", detail: "No breaches involving this domain are recorded in Have I Been Pwned.", severity: .pass),
            Finding(title: "Clean on VirusTotal", detail: "0 of 91 security vendors flag this domain as malicious.", severity: .pass),
            Finding(title: "VirusTotal reputation score", detail: "12 (community-driven; higher is better).", severity: .info),
            Finding(title: "Category", detail: "Information Technology (alphaMountain.ai), content server, computersandsoftware, information technology", severity: .info),
        ], summary: "No reputation issues found")

        return ScanReport(
            target: "example.com (demo)",
            date: Date(),
            results: [overview, subdomains, dns, ssl, http, ports, whois, reputation],
            isSample: true
        )
    }
}
