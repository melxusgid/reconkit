//
//  RemediationEngine.swift
//  ReconKit
//
//  Turns findings into prioritized, plain-English fixes. Keyed off the finding
//  title so the scan engine doesn't have to carry fix text everywhere.
//

import Foundation

struct ActionItem: Identifiable, Hashable {
    var id = UUID()
    var category: ScanCategory
    var finding: Finding
    var fix: String
}

enum RemediationEngine {
    /// Plain-English remediation for a finding, or nil if none applies.
    static func advice(for finding: Finding) -> String? {
        if let r = finding.remediation { return r }
        let t = finding.title.lowercased()

        switch true {
        case t.contains("dmarc"):
            return "Publish a DMARC record at _dmarc.<domain> — start with \"v=DMARC1; p=none; rua=mailto:you@domain\" to monitor, then tighten to p=quarantine or p=reject."
        case t.contains("spf"):
            return "Add a TXT record \"v=spf1 include:<your-mail-provider> -all\" listing every server allowed to send mail for the domain."
        case t.contains("dnssec"):
            return "Enable DNSSEC in your DNS provider's dashboard. It signs DNS answers so resolvers can detect spoofing/tampering."
        case t.contains("caa"):
            return "Add a CAA record (e.g. 0 issue \"letsencrypt.org\") so only the certificate authorities you choose can issue certs for the domain."
        case t.contains("hsts") || t.contains("strict-transport"):
            return "Send the header \"Strict-Transport-Security: max-age=63072000; includeSubDomains; preload\" so browsers always use HTTPS."
        case t.contains("content security") || t.contains("csp"):
            return "Add a Content-Security-Policy header restricting script/style sources (start in report-only mode) to mitigate XSS."
        case t.contains("x-frame") || t.contains("clickjack"):
            return "Send \"X-Frame-Options: DENY\" (or CSP frame-ancestors 'none') to prevent your pages being framed for clickjacking."
        case t.contains("x-content-type"):
            return "Send \"X-Content-Type-Options: nosniff\" to stop browsers MIME-sniffing responses."
        case t.contains("referrer-policy"):
            return "Send \"Referrer-Policy: strict-origin-when-cross-origin\" to limit referrer data leaking to other sites."
        case t.contains("legacy tls") || t.contains("negotiated tls 1.0") || t.contains("negotiated tls 1.1") || t.contains("no modern tls"):
            return "Disable TLS 1.0/1.1 in your server or CDN config and require TLS 1.2+ (ideally 1.3)."
        case t.contains("certificate expired"):
            return "Renew the TLS certificate immediately and automate renewal (e.g. ACME/Let's Encrypt) so it can't lapse again."
        case t.contains("expires in") || (t.contains("expiry") && finding.severity == .warning):
            return "Renew the TLS certificate soon and set up automated renewal to avoid an outage."
        case t.contains("port") && t.contains("open"):
            return "Confirm this service must be public. If not, firewall it or bind it to localhost/VPN. If it must be public, patch it and require authentication."
        case t.contains("subdomains") && finding.severity == .warning:
            return "Review the discovered subdomains. Decommission stale/forgotten hosts — they expand your attack surface and are common entry points."
        case t.contains("no http") || t.contains("unreachable"):
            return "Verify the host is online and serving HTTPS. If it should be reachable, check DNS and your web server/CDN configuration."
        default:
            return nil
        }
    }
}
